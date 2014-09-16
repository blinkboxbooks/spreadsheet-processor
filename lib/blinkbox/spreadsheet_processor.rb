require "blinkbox/spreadsheet_processor/version"
require "blinkbox/spreadsheet_processor/reader"
require "blinkbox/spreadsheet_processor/service"

    def found_spreadsheet(file)
      folder_name = File.join(File.dirname(file),"generated_" + File.basename(file))

      opts = default_opts(file)


      begin
        xl = case File.extname(file)
        when '.xls'
          Roo::Excel.new(file)
        when '.xlsx'
          Roo::Excelx.new(file)
        end
      rescue RuntimeError => e
        has_been_ignored(file)
        @log.warn({
          event_type: 'ingestion.spreadsheet.failure',
          exception: e,
          file: {
            uri: file,
            source: opts['publisher'],
            modified_at: opts['modified_at'].iso8601
          },
        })

        return
      end

      xl.default_sheet = xl.sheets.first

      xl.header_line = 1 # needed?

      headings = xl.row(1)

      if headings & REQUIRED_HEADINGS != REQUIRED_HEADINGS
        @log.error({
          message: "Spreadsheet does not have the required headings",
          event_type: 'ingestion.spreadsheet.failure',
          data: {
            expected_headings: REQUIRED_HEADINGS,
            provided_headings: headings
          },
          file: {
            uri: file,
            source: opts['publisher'],
            modified_at: opts['modified_at'].iso8601
          },
        })

        has_been_ignored(file)
        return
      end

      tmp_folder = Dir.mktmpdir

      begin
        2.upto(xl.last_row) do |row_num|
          row = Hash[headings.zip(xl.row(row_num))]
          
          validate_spreadsheet_row!(row)

          # map the row to a book object
          # NB. Only essential validation is done here, that will occur when the generated ONIX is ingested
          book = Blinkbox::Onix21.new({
            'data_source' => {
              'type' => "Converted spreadsheet",
              'uri' => file.split("/#{opts['publisher']}/").last,
              'created_at' => Time.now
            },
            'isbn' => row['eISBN 13'].to_i,
            'title' => row['Title'],
            'subtitle' => row['Subtitle'],
            'contributors' => (1..3).collect do |n|
              begin
                {
                  'display_name' => row["Contributor #{n}"],
                  'sort_name' => row["Contributor #{n} Inverted"],
                  'role' => CONTRIBUTOR_CODES[row["Contributor #{n} Role"].downcase],
                  'biography' => row["Contributor #{n} Bio"],
                  'image' => row["Contributor #{n} Photo URL"],
                }
              rescue
                nil
              end
            end.compact,
            'dates' => {
              # This should be captured as a date already
              'publish' => row['Publication Date']
            },
            'prices' => [
              {
                'includes_tax?' => false,
                'agency?' => false,
                'amount' => row['List Price ex VAT'],
                'currency' => row['Currency Type']
              },{
                'includes_tax?' => true,
                'agency?' => false,
                'amount' => row['List Price inc VAT'],
                'currency' => row['Currency Type']
              },
            ],
            'pages' => row['Page Count'],
            'imprint' => row['Imprint'],
            'publisher' => row['Publisher'],
            'language' => [row['Language']],
            'sellable_in' => (row['Territories'] || '').split(' '),
            'descriptions' => [
              {
                'content' => row['Description']
              }
            ],
            'subjects' => [
              'type' => 'BISAC',
              'code' => row['BISAC Main Subject'],
              'main' => true
            ] + (row['Additional BISAC Subjects (comma separated)'] || '').split(/,\s*/).collect do |code|
              {
                'type' => 'BISAC',
                'code' => code
              }
            end
          })

          # Generate the XML before we create the file to write to
          # in case there's an error
          xml = book.to_xml

          filename = File.join(tmp_folder,"#{book['isbn']}.xml")
  
          open(filename,"w") do |f|
            f.write xml
          end

          FileUtils.touch(filename,mtime: opts['modified_at'])
        end

        FileUtils.mv(tmp_folder, folder_name)
        FileUtils.chmod(0775, folder_name)

        @log.info({
          message: "Spreadsheet sucessfully converted to ONIX",
          event_type: 'ingestion.spreadsheet.complete',
          file: {
            uri: file,
            source: opts['publisher'],
            modified_at: opts['modified_at'].iso8601
          },
        })
        has_been_processed(file)
      rescue StandardError => e
        @log.error({
          exception: e,
          event_type: 'ingestion.spreadsheet.failure',
          file: {
            uri: file,
            source: opts['publisher'],
            modified_at: opts['modified_at'].iso8601
          },
        })

        FileUtils.rm_rf(tmp_folder)

        has_been_ignored(file)
      end
    end

    def validate_spreadsheet_row!(row)
      raise RuntimeError, "Language must be a three letter string (not: #{row['Language']})" unless row['Language'] =~ /^[a-z]{3}$/i

      # Some dates are given as floats. No, no idea why.
      row['Publication Date'] = Date.parse(row['Publication Date'].to_i.to_s) unless row['Publication Date'].respond_to? :strftime
    end

  end
end
