require "blinkbox/spreadsheet_processor/reader"

context Blinkbox::SpreadsheetProcessor::Reader do
  describe "#validate_spreadsheet_row_hash" do
    invalid_headings = {
      "eISBN 13" => "x",
      "Title" => nil,
      "Contributor 1" => nil, # on the assumption that there's a Contributor 1 Inverted
      "Contributor 1 Role" => nil,
      "Contributor 1 Photo URL" => "not a URL",
      "Contributor 2" => nil,
      "Contributor 2 Role" => nil,
      "Contributor 2 Photo URL" => "not a URL",
      "Contributor 3" => nil,
      "Contributor 3 Role" => nil,
      "Contributor 3 Photo URL" => "not a URL",
      "Publication Date" => "not a date",
      "List Price ex VAT" => "not a price",
      "List Price inc VAT" => "not a price",
      "Currency Type" => "not a currency code",
      "Page Count" => "Not a number",
      "Publisher" => nil, # Maybe this is allowed?
      "Language" => "Not a language code",
      "BISAC Main Subject" => "Not a BISAC code",
      "Additional BISAC Subjects (comma separated)" => "Not a BISAC code",
      "Territories" => "Not a territory code",
      "Description" => nil
    }

    contributor_roles = {
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

    # Returns a valid row with the additional components specified
    def valid_row(with: {})
      {
        'eISBN 13' => "9780111222333",
        'Title' => "A valid title",
        'Subtitle' => "A valid subtitle",
        'Language' => "eng",
        'Publication date' => "20140911",
        'Contributor 1' => "Too Small",
        'Contributor 1 Inverted' => "Small, Too",
        'Contributor 1 Role' => "Author",
        'Contributor 1 Bio' => "This bear was just too small.",
        'Contributor 1 Photo URL' => "http://path.to/small.jpg",
        'Contributor 2' => "Too Big",
        'Contributor 2 Inverted' => "Big, Too",
        'Contributor 2 Role' => "Author",
        'Contributor 2 Bio' => "This bear was just too big.",
        'Contributor 2 Photo URL' => "http://path.to/big.jpg",
        'Contributor 3' => "Just Right",
        'Contributor 3 Inverted' => "Right, Just",
        'Contributor 3 Role' => "Author",
        'Contributor 3 Bio' => "This bear was just right!",
        'Contributor 3 Photo URL' => "http://path.to/small.jpg"
      }.merge(with)
    end

    def empty_contributor(number)
      {
        "Contributor #{number}" => nil,
        "Contributor #{number} Inverted" => nil,
        "Contributor #{number} Role" => nil,
        "Contributor #{number} Bio" => nil,
        "Contributor #{number} Photo URL" => nil,
      }
    end

    describe "for isbns" do
      ["9780111222333", "9781234567890", "9790987654321", 9780111222333].each do |isbn|
        it "must accept ISBNs: (#{isbn.class}) #{isbn}" do
          row = valid_row(with: {
            'eISBN 13' => isbn
          })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          expect(book[:isbn]).to eq(isbn.to_s)
        end
      end

      it "must reject a row with an invalid ISBN" do
        row = valid_row(with: {
          'eISBN 13' => "notanisbn"
        })

        book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(1)
        expect(issues.first[:error_code]).to eq("isbn.invalid")
        expect(book[:isbn]).to be_nil
      end
    end

    describe "for titles" do
      it "must accept titles" do
        title = "Hi I'm a title"
        row = valid_row(with: { 'Title' => title })

        book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect(book[:title]).to eq(title)
      end

      it "must reject a row with an empty title" do
        title = ""
        row = valid_row(with: { 'Title' => title })

        book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(1)
        expect(issues.first[:error_code]).to eq("title.invalid")
        expect(book[:title]).to be_nil
      end
    end

    describe "for subtitles" do
      it "must accept subtitles" do
        subtitle = "Hi I'm a subtitle"
        row = valid_row(with: { 'Subtitle' => subtitle })

        book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect(book[:subtitle]).to eq(subtitle)
      end

      it "must accept a row with a missing subtitle" do
        subtitle = ""
        row = valid_row(with: { 'Subtitle' => subtitle })

        book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect(book[:subtitle]).to be_nil
      end
    end

    describe "for languages" do
      ["eng", "ENG", "fra"].each do |language|
        it "must accept languages: #{language}" do
          row = valid_row(with: { 'Language' => language })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          expect(book[:language]).to eq([language.downcase])
        end
      end

      ["english", "", nil].each do |language|
        it "must reject a row with an empty language" do
          row = valid_row(with: { 'Language' => language })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(1)
          expect(issues.first[:error_code]).to eq("language.invalid")
          expect(book[:language]).to be_nil
        end
      end
    end

    describe "for dates" do
      ["2014-09-11", "20140911", Date.new(2014, 9, 11)].each do |date|
        it "must accept publication dates: #{date}" do
          row = valid_row(with: { 'Publication date' => date })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          expect(book[:dates]).to be_a(Hash)
          expect(book[:dates][:publish]).to eq(Date.new(2014, 9, 11))
        end
      end

      ["09-11-2014", "01-30-2014", "11092014", 1410431742].each do |date|
        it "must reject a row with invalid publication dates" do
          row = valid_row(with: { 'Publication date' => date })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(1)
          expect(issues.first[:error_code]).to eq("publish_date.invalid")
          expect((book[:dates] || {})[:publish]).to_not be_a(Date)
        end
      end
    end
    
    %w{1 2 3}.each do |contributor_n|
      describe "for contributor #{contributor_n}" do
        it "must accept a non-empty contributor name" do
          name = "Testy McTest #{contributor_n}"
          row = valid_row(with: { "Contributor #{contributor_n}" => name })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book[:contributors][contributor_n.to_i - 1]
          expect(contributor[:names][:display]).to eq(name)
        end

        it "must reject an empty string as a contributor name if other contributor components are present" do
          row = valid_row(with: { "Contributor #{contributor_n}" => "" })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(1)
          expect(issues.first[:error_code]).to eq("contributor.invalid")
        end

        it "must accept a non-empty string as an inverted name" do
          iname = "McTest #{contributor_n}, Testy"
          row = valid_row(with: { "Contributor #{contributor_n} Inverted" => iname })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book[:contributors][contributor_n.to_i - 1]
          expect(contributor[:names][:sort]).to eq(iname)
        end

        it "must generate an inverted name if one isn't present" do
          name = "Testy McTest #{contributor_n}"
          iname = "McTest #{contributor_n}, Testy"
          row = valid_row(with: {
            "Contributor #{contributor_n}" => name,
            "Contributor #{contributor_n} Inverted" => ""
          })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book[:contributors][contributor_n.to_i - 1]
          expect(contributor[:names][:sort]).to eq(iname)
        end

        contributor_roles.each do |role, code|
          it "must accept the #{role} role" do
            row = valid_row(with: { "Contributor #{contributor_n} Role" => role })

            book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
            expect(issues.size).to eq(0)
            contributor = book[:contributors][contributor_n.to_i - 1]
            expect(contributor[:role]).to eq(code)
          end
        end

        it "must reject a row an unknown role" do
          row = valid_row(with: { "Contributor #{contributor_n} Role" => "Lord of Writing" })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(1)
          expect(issues.first[:error_code]).to eq("contributor.invalid")
        end

        it "must accept a non-empty contributor biography" do
          bio = "Biography for contributor ##{contributor_n}"
          row = valid_row(with: { "Contributor #{contributor_n} Bio" => bio })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book[:contributors][contributor_n.to_i - 1]
          expect(contributor[:biography]).to eq(bio)
        end

        it "must accept an empty string as an absent biography" do
          row = valid_row(with: { "Contributor #{contributor_n} Bio" => "" })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book[:contributors][contributor_n.to_i - 1]
          expect(contributor).to_not have_key(:biography)
        end

        it "must accept a valid URL as the remote profile photo for a contributor" do
          url = "http://path.to/an/interesting/photo/for/contributor/#{contributor_n}.jpg"
          row = valid_row(with: { "Contributor #{contributor_n} Photo URL" => url })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book[:contributors][contributor_n.to_i - 1]
          images = contributor[:media][:images]
          expect(images.size).to eq(1)
          expect(images.first[:classification]).to eq([{ realm: "type", id: "profile" }])
          expect(images.first[:uris].size).to eq(1)
          expect(images.first[:uris].first[:type]).to eq("remote")
          expect(images.first[:uris].first[:uri]).to eq(url)
        end

        it "must accept an empty string as an absent profile photo for a contributor" do
          row = valid_row(with: { "Contributor #{contributor_n} Photo URL" => "" })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          contributor = book[:contributors][contributor_n.to_i - 1]
          images = (contributor[:media] || {})[:images] || []
          expect(images.size).to eq(0)
        end

        it "must reject an invalid URL as the remote profile photo for a contributor" do
          row = valid_row(with: { "Contributor #{contributor_n} Photo URL" => "just a string" })

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(1)
          expect(issues.first[:error_code]).to eq("contributor.invalid")
        end
      end
    end

    describe "for combined contributors" do
      it "must accept rows with Contributor 1 data, but no Contributor 2 or 3 data" do
        extra = empty_contributor(2).merge(empty_contributor(3))
        row = valid_row(with: extra)

        book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
      end

      it "must accept rows with Contributor 1 and 2 data, but no Contributor 3 data" do
        row = valid_row(with: empty_contributor(3))

        book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
      end

      it "must reject rows with Contributor 2 data, but no Contributor 1 or 3 data" do
        extra = empty_contributor(3).merge(empty_contributor(1))
        row = valid_row(with: extra)

        book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(1)
        expect(issues.first[:error_code]).to eq("contributors.invalid")
      end

      it "must reject rows with Contributor 2 and 3 data, but no Contributor 1 data" do
        row = valid_row(with: empty_contributor(1))

        book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(1)
        expect(issues.first[:error_code]).to eq("contributors.invalid")
      end

      it "must reject rows with Contributor 3 data, but no Contributor 1 or 2 data" do
        extra = empty_contributor(2).merge(empty_contributor(1))
        row = valid_row(with: extra)

        book, issues = described_class.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(1)
        expect(issues.first[:error_code]).to eq("contributors.invalid")
      end

    end

    describe "for issues" do
      invalid_headings.each do |heading, invalid_value|
        it "must include cell references in the issue object for invalid #{heading}" do
          row = valid_row(with: { heading => invalid_value })

          column_num = row.keys.index(heading)
          row_num = 3
          cell_reference = "#{Roo::Base.number_to_letter(column_num)}#{row_num}"

          book, issues = described_class.send(:validate_spreadsheet_row_hash, row, row_num)
          expect(issues.size).to eq(1)

          expect(issues.first[:data][:row]).to eq(row_num)
          expect(issues.first[:data][:column]).to eq(column_num)
          expect(issues.first[:data][:cell_reference]).to eq(cell_reference)
        end
      end
    end
  end
end