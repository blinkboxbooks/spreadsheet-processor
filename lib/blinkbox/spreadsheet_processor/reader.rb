require "roo"
require "sanitize"

module Blinkbox
  module SpreadsheetProcessor
    class Reader
      attr_reader :valid_html

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
        "eISBN 13" => proc { |field|
          if field.to_s =~ /^(\d{13})(?:\.0)?$/
            {
              data: { "isbn" => Regexp.last_match[1] }
            }
          else
            {
              error_code: "isbn.invalid",
              message: "'eISBN 13' is not a valid ISBN"
            }
          end
        },
        "Title" => proc { |field|
          val = field.to_s
          if val.empty?
            {
              error_code: "title.invalid",
              message: "'Title' cannot be empty"
            }
          else
            {
              data: { "title" => val }
            }
          end
        },
        "Subtitle" => proc { |field|
          val = field.to_s
          if val.empty?
            data = {}
          else
            data  ={ "subtitle" => val}
          end
          {
            data: data
          }
        },
        "Contributor 1" => (contributor = proc { |data|
          present = data.select { |k, v| !v.to_s.empty? }.keys
          next { data: {} } if present.empty?

          # Names
          next {
            error_code: "contributor.invalid",
            message: "Contributor name must be present if any other fields are not empty (#{present.join(", ")})"
          } if !present.include?("Name")

          # Deal with missing inverted names, which isn't a failing issue
          if data["Inverted"].to_s.empty?
            parts = data["Name"].split(" ")
            first = parts.shift
            data["Inverted"] = [parts.join(" "), first].join(", ")
          end
          contributor = {
            "classification" => [],
            "names" => {
              "display" => data["Name"],
              "sort" => data["Inverted"]
            }
          }

          # Role
          next {
            error_code: "contributor.invalid",
            field_suffix: "Role",
            message: "Contributor Role must is invalid"
          } if !CONTRIBUTOR_ROLES.has_key?(data["Role"].to_s.downcase)

          contributor["role"] = CONTRIBUTOR_ROLES[data["Role"].to_s.downcase]

          # Biography
          contributor["biography"] = data["Bio"] unless data["Bio"].to_s.empty? 

          # Photo URL
          if !data["Photo URL"].to_s.empty?
            next {
              error_code: "contributor.invalid",
              field_suffix: "Photo URL",
              message: "Contributor Photo URL must be a URL"
            } unless data["Photo URL"] =~ URI.regexp

            contributor["media"] = {
              "images" => [{
                "classification" => [{
                  "realm" => "type",
                  "id" => "profile"
                }],
                "uris" => [{
                  "type" => "remote",
                  "uri" => data["Photo URL"]
                }]
              }]
            }
          end

          {
            data: {
              contributors: [contributor]
            }
          }
        }),
        "Contributor 2" => contributor.dup,
        "Contributor 3" => contributor.dup,
        "Publication Date" => proc { |field|
          if !field.respond_to?(:strftime)
            if field.to_s =~ /^(?<year>(?:16|17|18|19|20)\d\d)-?(?<month>\d\d)-?(?<day>\d\d)(?:\.0)?$/
              parts = Regexp.last_match
              field = Date.new(parts[:year].to_i, parts[:month].to_i, parts[:day].to_i)
            else
              next {
                error_code: "publish_date.invalid",
                message: "'Publication date' must be a date in the format YYYYMMDD"
              }
            end
          end
          {
            data: {
              "dates" => {
                "publish" => field
              }
            }
          }
        },
        "Language" => proc { |field|
          if field =~ /^[a-z]{3}$/i
            {
              data: { "language" => [field.downcase] }
            }
          else
            {
              error_code: "language.invalid",
              message: "'Language' must be a three letter word."
            }
          end
        },
        "List Price ex VAT" => proc { |field|
          next {
            error_code: "ex_vat_price.invalid",
            message: "ex VAT price must be a number."
          } unless field.to_s =~ /^\d+(?:\.\d+)?$/
          {
            data: {
              prices: [{
                "amount" => field.to_f,
                "includesTax?" => false
              }]
            }
          }
        },
        "List Price inc VAT" => proc { |field|
          next {
            error_code: "inc_vat_price.invalid",
            message: "inc VAT price must be a number."
          } unless field.to_s =~ /^\d+(?:\.\d+)?$/
          {
            data: {
              prices: [{
                "amount" => field.to_f,
                "includesTax?" => true
              }]
            }
          }
        },
        "Currency Type" => proc { |field|
          next {
            error_code: "currency.invalid",
            message: "Currency must be a three letter currency code."
          } unless field.to_s =~ /^[A-Z]{3}$/i
          {
            data: {
              "x-currency" => field.upcase
            }
          }
        },
        "Page Count" => proc { |field|
          next { data: {} } if field.nil? || field.to_s.empty?
          next {
            error_code: "page_count.invalid",
            message: "Page count must be an integer or empty"
          } unless field.to_s =~ /^\d+$/
          {
            data: {
              "pages" => field.to_i
            }
          }
        },
        "Publisher" => proc { |field|
          next {
            error_code: "publisher.invalid",
            message: "A publisher must be specified"
          } if field.nil? || field.to_s.empty?
          {
            data: {
              "publisher" => field
            }
          }
        },
        "BISAC Main Subject" => proc { |field|
          next {
            error_code: "main_bisac.invalid",
            message: "BISAC codes are three letters followed by 6 numbers."
          } unless field =~ /^[A-Z]{3}\d{6}$/i
          {
            data: {
              subjects: [{
                "type" => "BISAC",
                "code" => field
              }]
            }
          }
        },
        "Additional BISAC Subjects (comma separated)" => proc { |field|
          codes = field.to_s.split(/[,;\ ]\ ?/)
          next {
            error_code: "additional_bisac.invalid",
            message: "BISAC codes are three letters followed by 6 numbers, and must be separated with spaces, commas or semicolons."
          } if codes.select { |code| !code.match(/^[A-Z]{3}\d{6}$/i) }.any?
          {
            data: {
              subjects: codes.map { |code|
                {
                  "type" => "BISAC",
                  "code" => code
                }
              }
            }
          }
        },
        "Description" => proc { |field|
          next {
            error_code: "description.invalid",
            message: "A description must be given for the book."
          } if field.to_s.empty?

          {
            data: {
              "descriptions" => [{
                "classification" => [{
                  "realm" => "onix_other_text_type_code",
                  "id" => "01"
                }],
                "content" => Sanitize.clean(field.to_s, @valid_html)
              }]
            }
          }
        },
        "Territories" => proc { |field|
          codes = field.to_s.split(/[,;\ ]\ ?/)
          next {
            error_code: "territories.invalid",
            message: "Territory codes must be two letter words or 'WORLD'."
          } if codes.empty? || codes.select { |code| !code.match(/^([A-Z]{2}|WORLD)$/i) }.any?
          {
            data: {
              "regionalRights" => Hash[codes.map { |code|
                [code.upcase, true]
              }]
            }
          }
        }
      }

      def initialize(filename, format: File.extname(filename)[1..-1].downcase.to_sym, valid_html: Sanitize::Config::RELAXED)
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
        @valid_html = valid_html 
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
          book, issues = validate_spreadsheet_row_hash(row, row_num)

          if issues.any?
            failures.push(*issues)
            next
          end

          yield book
        end

        failures
      end

      private

      def validate_spreadsheet_row_hash(row, row_number)
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
        issues = []
        contributor_columns_used = []

        CELL_VALIDATION.each do |field_name, validator|
          validation_result = instance_exec(row[field_name], &validator)
          contributor_columns_used.push(Regexp.last_match[1].to_i) if field_name =~ /^Contributor (\d)$/ && validation_result[:data] != {}

          if !validation_result[:error_code]
            data = validation_result[:data]
            data.keys.each do |key|
              next unless key.is_a?(Symbol)
              # Symbol keys should be treated like arrays and merged
              data[key.to_s] = (book[key.to_s] || []) + data[key]
              data.delete(key)
            end
            book.merge!(data)

            # All good! No need to push an issue
            next
          end

          # This is so we can reference the specific column which failed within the contributors
          field_name = [field_name, validation_result[:field_suffix]].compact.join(" ") if validation_result[:field_suffix]

          validation_result[:data] = cell_reference(field_name, row_number, row_headers).merge(
            field_name: field_name,
            value: row[field_name],
            value_type: row[field_name].class
          )
          issues.push(validation_result)
        end

        # Set the currency of all prices
        currency = book["x-currency"]
        book["prices"].each do |price|
          price["currency"] = currency
        end

        missing_contributors = (1..(book["contributors"] || []).size).to_a - contributor_columns_used
        if missing_contributors.any?
          field_name = "Contributor #{missing_contributors.min}"
          issues.push(
            error_code: "contributor.missing",
            message: "A contributor was specified without all previous contributors.",
            data: cell_reference(field_name, row_number, row_headers).merge(
              field_name: field_name
            )
          )
        end

        [book, issues]
      end

      def cell_reference(header, row_number, row_headers)
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