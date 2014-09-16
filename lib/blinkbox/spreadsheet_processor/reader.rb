require "roo"
require "blinkbox/onix/onix21"

module Blinkbox
  module SpreadsheetProcessor
    class Reader
      REQUIRED_HEADINGS = ["eISBN 13", "Title", "Subtitle", "Contributor 1", "Contributor 1 Inverted", "Contributor 1 Role", "Contributor 1 Bio", "Contributor 1 Photo URL", "Contributor 2", "Contributor 2 Inverted", "Contributor 2 Role", "Contributor 2 Bio", "Contributor 2 Photo URL", "Contributor 3", "Contributor 3 Inverted", "Contributor 3 Role", "Contributor 3 Bio", "Contributor 3 Photo URL", "Publication Date", "List Price ex VAT", "List Price inc VAT", "Currency Type", "Page Count", "Imprint", "Publisher", "Language", "BISAC Main Subject", "Additional BISAC Subjects (comma separated)", "Territories", "Description"]
      CONTRIBUTOR_ROLES = {
        'author'       => 'A01',
        'illustrator'  => 'A12',
        'preface'      => 'A15',
        'prologue'     => 'A16',
        'afterword'    => 'A19',
        'notes'        => 'A20',
        'foreword'     => 'A23',
        'introduction' => 'A24',
        'editor'       => 'B01',
        'translator'   => 'B06'
      }
      # A hash detailing the validation for each required heading
      CELL_VALIDATION = {
        "eISBN 13" => {
          error_code: "isbn.invalid",
          valid: proc { |field|
            if field.to_s =~ /^(?:9780|9781|979\d)\d{9}$/
              { isbn: field.to_s }
            else
              "'eISBN 13' is not a valid ISBN"
            end
          }
        },
        "Title" => {
          error_code: "title.invalid",
          valid: proc { |field|
            val = field.to_s
            if val.empty?
              "'Title' cannot be empty"
            else
              { title: val }
            end
          }
        },
        "Subtitle" => {
          # Subtitle is always valid
          valid: proc { |field|
            val = field.to_s
            if val.empty?
              {}
            else
              { subtitle: val}
            end
          }
        },
        "Contributor 1" => (contributor = {
          error_code: "contributor.invalid",
          valid: proc { |data|
            present = data.select { |k, v| !v.to_s.empty? }.keys
            next {} if present.empty?

            # Names
            next [nil, "Contributor name must be present if any other fields are not empty (#{present.join(", ")})"] if !present.include?("Name")
            # Deal with missing inverted names, which isn't a failing issue
            if data["Inverted"].to_s.empty?
              parts = data["Name"].split(" ")
              first = parts.shift
              data["Inverted"] = [parts.join(" "), first].join(", ")
            end
            doc = {
              contributor: {
                names: {
                  display: data["Name"],
                  sort: data["Inverted"]
                }
              }
            }

            # Role
            next ["Role", "Contributor Role must is invalid"] if !CONTRIBUTOR_ROLES.has_key?(data["Role"].to_s.downcase)
            doc[:contributor][:role] = CONTRIBUTOR_ROLES[data["Role"].to_s.downcase]

            # Biography
            doc[:contributor][:biography] = data["Bio"] unless data["Bio"].to_s.empty? 

            # Photo URL
            if !data["Photo URL"].to_s.empty?
              next ["Photo URL", "Contributor Photo URL must be a URL"] unless data["Photo URL"] =~ URI.regexp
              doc[:contributor][:media] = {
                images: [{
                  classification: [{
                    realm: "type",
                    id: "profile"
                  }],
                  uris: [{
                    type: "remote",
                    uri: data["Photo URL"]
                  }]
                }]
              }
            end

            doc
          }
        }),
        "Contributor 2" => contributor.dup,
        "Contributor 3" => contributor.dup,
        "Publication date" => {
          error_code: "publish_date.invalid",
          valid: proc { |field|
            if !field.respond_to?(:strftime)
              if field.to_s =~ /^(?<year>(?:16|17|18|19|20)\d\d)-?(?<month>\d\d)-?(?<day>\d\d)$/
                parts = Regexp.last_match
                field = Date.new(parts[:year].to_i, parts[:month].to_i, parts[:day].to_i)
              else
                next "'Publication date' must be a date in the format YYYYMMDD"
              end
            end
            { dates: { publish: field } }
          }
        },
        "Language" => {
          error_code: "language.invalid",
          valid: proc { |field|
            if field =~ /^[a-z]{3}$/i
              { language: [field.downcase] }
            else
              "'Language' must be a three letter word."
            end
          }
        }
      }

      def initialize(filename, format: File.extname(filename)[1..-1].downcase.to_sym)
        @roo = case format
        when :xls
          Roo::Excel.new(filename)
        when :xlsx
          Roo::Excelx.new(filename)
        when :csv
          Roo::CSV.new(filename)
        else
          raise ArgumentError, "Reader cannot cope with #{format} format spreadsheets."
        end

        # General set up for the spreadsheets
        @roo.default_sheet = @roo.sheets.first
        @roo.header_line = 1
      end

      def each_book
        raise ArgumentError, "You must call each_book with a block" unless block_given?
        failures = []
        @headings = @roo.row(1)

        if @headings & REQUIRED_HEADINGS != REQUIRED_HEADINGS
          backtrace = caller
          data = {
            missing_headers: REQUIRED_HEADINGS - @headings,
            extra_headers: @headings - REQUIRED_HEADINGS
          }
          
          failures << {
            error_code: "headers.incorrect",
            backtrace: backtrace,
            message: "Incorrect headers in ingested spreadsheet",
            data: data
          }

          return failures
        end

        2.upto(@roo.last_row) do |row_num|
          row = Hash[@headings.zip(@roo.row(row_num))]
          book, issues = self.validate_spreadsheet_row(row, row_number)

          if issues.any?
            failures.push(*issues)
            next
          end

          yield book
        end

        failures
      end

      private

      def self.validate_spreadsheet_row_hash(row, row_number)
        row_headers = row.keys
        # Map the contributor information into one hash
        1.upto(3) do |n|
          contributor = row.select { |k, v| k =~ /^Contributor #{n}/ }
          contributor.keys.each { |k| row.delete(k) }
          row["Contributor #{n}"] = Hash[contributor.map { |key, value|
            actual = key.sub(/^Contributor #{n} ?/, '')
            actual = "Name" if actual.empty?
            [actual, value]
          }]
        end
        # Process the row
        book = {}
        issues = CELL_VALIDATION.map { |field_name, details|
          details = details.dup
          validation_result = details.delete(:valid).call(row[field_name])
          if validation_result.is_a?(Hash)
            if validation_result[:contributor]
              # Contributors are a special case, as they need to merge into an array
              validation_result = {
                contributors: (book[:contributors] ||= []).push(validation_result[:contributor])
              }
            end
            book.merge!(validation_result)

            nil
          else
            if validation_result.is_a?(Array)
              details[:message] = validation_result[1]
              # This is so we can reference the specific column which failed within the contributors
              field_name = [field_name, validation_result[0]].compact.join(" ")
            else
              details[:message] = validation_result
            end

            details[:data] = cell_reference(field_name, row_number, row_headers).merge(
              field_name: field_name
            )
            details  
          end
        }.compact

        [book, issues]
      end

      def self.cell_reference(header, row_number, row_headers)
        col_number = row_headers.index(header)
        cell_reference = col_number.nil? ? "-" : "#{Roo::Base.number_to_letter(col_number)}#{row_number}"
        {
          row: row_number,
          column: col_number,
          cell_reference: cell_reference
        }
      end
    end
  end
end