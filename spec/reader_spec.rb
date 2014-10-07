require "blinkbox/spreadsheet_processor/reader"

context Blinkbox::SpreadsheetProcessor::Reader do
  describe "#validate_spreadsheet_row_hash" do
    subject(:reader) {
      reader = described_class.allocate
      reader.instance_variable_set(:'@valid_html', Sanitize::Config::RELAXED)
      reader
    }

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
      "Publisher" => nil,
      "Language" => "Not a language code",
      "BISAC Main Subject" => "Not a BISAC code",
      "Additional BISAC Subjects (comma separated)" => "Not a BISAC code",
      "Territories" => "NotATerritoryCode",
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
        'Publication Date' => "20140911",
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
        'Contributor 3 Photo URL' => "http://path.to/small.jpg",
        'Publication Date' => "2014-01-01",
        'List Price ex VAT' => 10.00,
        'List Price inc VAT' => 12.00,
        'Currency Type' => "GBP",
        'Page Count' => 123,
        'Publisher' => "Awesome Publishing",
        'Language' => "eng",
        'BISAC Main Subject' => "FIC005000",
        'Additional BISAC Subjects (comma separated)' => "SEL006000, HEA015000",
        'Territories' => "GB",
        'Description' => "This is a description about this book."
      }.merge(with)
    end

    def empty_contributor(number)
      {
        "Contributor #{number}" => nil,
        "Contributor #{number} Inverted" => nil,
        "Contributor #{number} Role" => nil,
        "Contributor #{number} Bio" => nil,
        "Contributor #{number} Photo URL" => nil
      }
    end

    describe "for isbns" do
      ["9780111222333", "9781234567890", "9790987654321", 9780111222333, 9780111222333.0].each do |isbn|
        it "must accept ISBNs: (#{isbn.class}) #{isbn}" do
          row = valid_row(with: {
            'eISBN 13' => isbn
          })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          expect(book["isbn"]).to eq(isbn.to_i.to_s)
        end
      end

      it "must reject a row with an invalid ISBN" do
        row = valid_row(with: {
          'eISBN 13' => "notanisbn"
        })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(1), "An incorrect number of issues was received (#{issues.map{ |i| i["message"] }.join(", ")}"
        expect(issues.map { |i| i[:error_code] }).to include("isbn.invalid")
      end
    end

    describe "for titles" do
      it "must accept titles" do
        title = "Hi I'm a title"
        row = valid_row(with: { 'Title' => title })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect(book["title"]).to eq(title)
      end

      it "must reject a row with an empty title" do
        title = ""
        row = valid_row(with: { 'Title' => title })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.map { |i| i[:error_code] }).to include("title.invalid")
        expect(book["title"]).to be_nil
      end
    end

    describe "for subtitles" do
      it "must accept subtitles" do
        subtitle = "Hi I'm a subtitle"
        row = valid_row(with: { 'Subtitle' => subtitle })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect(book["subtitle"]).to eq(subtitle)
      end

      it "must accept a row with a missing subtitle" do
        subtitle = ""
        row = valid_row(with: { 'Subtitle' => subtitle })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect(book["subtitle"]).to be_nil
      end
    end

    describe "for languages" do
      ["eng", "ENG", "fra"].each do |language|
        it "must accept languages: #{language}" do
          row = valid_row(with: { 'Language' => language })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          expect(book["language"]).to eq([language.downcase])
        end
      end

      ["english", "", nil].each do |language|
        it "must reject a row with an empty language" do
          row = valid_row(with: { 'Language' => language })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("language.invalid")
          expect(book["language"]).to be_nil
        end
      end
    end

    describe "for dates" do
      ["2014-09-11", "2014/09/11", "20140911", Date.new(2014, 9, 11), 20140911.0].each do |date|
        it "must accept publication dates: (#{date.class}) #{date}" do
          row = valid_row(with: { 'Publication Date' => date })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          expect(book["dates"]).to be_a(Hash)
          expect(book["dates"]["publish"]).to eq(Time.utc(2014, 9, 11).iso8601)
        end
      end

      ["11-09-2014", "11/09/2014", "11/9/2014"].each do |date|
        it "must assume inverted dates are in British order: #{date}" do
          row = valid_row(with: { 'Publication Date' => date })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          expect(book["dates"]).to be_a(Hash)
          expect(book["dates"]["publish"]).to eq(Time.utc(2014, 9, 11).iso8601)
        end
      end

      it "must return an ISO 8601 timestamp with time component if Roo gives a Time object" do
        time = Time.utc(2014, 9, 11, 13, 10, 53)
        row = valid_row(with: { 'Publication Date' =>  time })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect(book["dates"]).to be_a(Hash)
        expect(book["dates"]["publish"]).to eq(time.iso8601)
      end


      [invalid_headings['Publication Date'], "01-30-2014", 1410431742].each do |date|
        it "must reject a row with invalid publication date: (#{date.class}) #{date}" do
          row = valid_row(with: { 'Publication Date' => date })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("publish_date.invalid")
          expect((book["dates"] || {})["publish"]).to_not be_a(Date)
        end
      end
    end
    
    %w{1 2 3}.each do |contributor_n|
      describe "for contributor #{contributor_n}" do
        it "must accept a non-empty contributor name" do
          name = "Testy McTest #{contributor_n}"
          row = valid_row(with: { "Contributor #{contributor_n}" => name })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book["contributors"][contributor_n.to_i - 1]
          expect(contributor["names"]["display"]).to eq(name)
        end

        it "must reject an empty string as a contributor name if other contributor components are present" do
          row = valid_row(with: { "Contributor #{contributor_n}" => "" })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("contributor.invalid")
        end

        it "must accept a non-empty string as an inverted name" do
          iname = "McTest #{contributor_n}, Testy"
          row = valid_row(with: { "Contributor #{contributor_n} Inverted" => iname })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book["contributors"][contributor_n.to_i - 1]
          expect(contributor["names"]["sort"]).to eq(iname)
        end

        it "must generate an inverted name if one isn't present" do
          name = "Testy McTest #{contributor_n}"
          iname = "McTest #{contributor_n}, Testy"
          row = valid_row(with: {
            "Contributor #{contributor_n}" => name,
            "Contributor #{contributor_n} Inverted" => ""
          })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book["contributors"][contributor_n.to_i - 1]
          expect(contributor["names"]["sort"]).to eq(iname)
        end

        contributor_roles.each do |role, code|
          it "must accept the #{role} role" do
            row = valid_row(with: { "Contributor #{contributor_n} Role" => role })

            book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
            expect(issues.size).to eq(0)
            contributor = book["contributors"][contributor_n.to_i - 1]
            expect(contributor["role"]).to eq(code)
          end
        end

        it "must reject a row an unknown role" do
          row = valid_row(with: { "Contributor #{contributor_n} Role" => "Lord of Writing" })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("contributor.invalid")
        end

        it "must accept a non-empty contributor biography" do
          bio = "Biography for contributor ##{contributor_n}"
          row = valid_row(with: { "Contributor #{contributor_n} Bio" => bio })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book["contributors"][contributor_n.to_i - 1]
          expect(contributor["biography"]).to eq(bio)
        end

        it "must accept an empty string as an absent biography" do
          row = valid_row(with: { "Contributor #{contributor_n} Bio" => "" })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book["contributors"][contributor_n.to_i - 1]
          expect(contributor).to_not have_key(:biography)
        end

        it "must accept a valid URL as the remote profile photo for a contributor" do
          url = "http://path.to/an/interesting/photo/for/contributor/#{contributor_n}.jpg"
          row = valid_row(with: { "Contributor #{contributor_n} Photo URL" => url })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          contributor = book["contributors"][contributor_n.to_i - 1]
          images = contributor["media"]["images"]
          expect(images.size).to eq(1)
          expect(images.first["classification"]).to eq([{ "realm" => "type", "id" => "profile" }])
          expect(images.first["uris"].size).to eq(1)
          expect(images.first["uris"].first["type"]).to eq("remote")
          expect(images.first["uris"].first["uri"]).to eq(url)
        end

        it "must accept an empty string as an absent profile photo for a contributor" do
          row = valid_row(with: { "Contributor #{contributor_n} Photo URL" => "" })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          contributor = book["contributors"][contributor_n.to_i - 1]
          images = (contributor["media"] || {})["images"] || []
          expect(images.size).to eq(0)
        end

        it "must reject an invalid URL as the remote profile photo for a contributor" do
          row = valid_row(with: { "Contributor #{contributor_n} Photo URL" => "just a string" })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("contributor.invalid")
        end
      end
    end

    describe "for combined contributors" do
      it "must accept rows with Contributor 1 data, but no Contributor 2 or 3 data" do
        extra = empty_contributor(2).merge(empty_contributor(3))
        row = valid_row(with: extra)

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
      end

      it "must accept rows with Contributor 1 and 2 data, but no Contributor 3 data" do
        row = valid_row(with: empty_contributor(3))

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
      end

      it "must reject rows with Contributor 2 data, but no Contributor 1 or 3 data" do
        extra = empty_contributor(3).merge(empty_contributor(1))
        row = valid_row(with: extra)

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.map { |i| i[:error_code] }).to include("contributor.missing")
      end

      it "must reject rows with Contributor 2 and 3 data, but no Contributor 1 data" do
        row = valid_row(with: empty_contributor(1))

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.map { |i| i[:error_code] }).to include("contributor.missing")
      end

      it "must reject rows with Contributor 3 data, but no Contributor 1 or 2 data" do
        extra = empty_contributor(2).merge(empty_contributor(1))
        row = valid_row(with: extra)

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.map { |i| i[:error_code] }).to include("contributor.missing")
      end
    end

    describe "for prices" do
      ["2.00", 2.00, 2].each do |amt|
        it "must accept numbers as ex VAT price: (#{amt.class}) #{amt.inspect}" do
          row = valid_row(with: { 'List Price ex VAT' => amt })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          ex_vat_prices = (book["prices"] || []).select { |p| p["includesTax?"] === false }
          expect(ex_vat_prices.size).to eq(1)
          expect(ex_vat_prices.first["amount"]).to eq(amt.to_f)
        end
      end

      ["", nil, "two"].each do |amt|
        it "must reject a row with non-numbers in the ex VAT price column: (#{amt.class}) #{amt.inspect}" do
          row = valid_row(with: { 'List Price ex VAT' => amt })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("ex_vat_price.invalid")
          ex_vat_prices = (book["prices"] || []).select { |p| p["includesTax?"] === false }
          expect(ex_vat_prices.size).to eq(0)
        end
      end

      ["2.00", 2.00, 2].each do |amt|
        it "must accept numbers as inc VAT price: (#{amt.class}) #{amt.inspect}" do
          row = valid_row(with: { 'List Price inc VAT' => amt })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          inc_vat_prices = (book["prices"] || []).select { |p| p["includesTax?"] === true }
          expect(inc_vat_prices.size).to eq(1)
          expect(inc_vat_prices.first["amount"]).to eq(amt.to_f)
        end
      end

      ["", nil, "two"].each do |amt|
        it "must reject a row with non-numbers in the inc VAT price column: (#{amt.class}) #{amt.inspect}" do
          row = valid_row(with: { 'List Price inc VAT' => amt })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("inc_vat_price.invalid")
          inc_vat_prices = (book["prices"] || []).select { |p| p["includesTax?"] === true }         
          expect(inc_vat_prices.size).to eq(0)
        end
      end

      ["GBP", "gbp", "USD", "EUR"].each do |code|
        it "must accept three letter currency codes: #{code}" do
          row = valid_row(with: { 'Currency Type' => code })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          prices_with_correct_currency_codes = (book["prices"] || []).select { |p| p["currency"] == code.upcase }
          expect(prices_with_correct_currency_codes.size).to eq(2)
        end
      end

      it "must assume rows are wholesale prices" do
        book, issues = reader.send(:validate_spreadsheet_row_hash, valid_row, 0)
        expect(issues.size).to eq(0)
        wholesale_prices = (book["prices"] || []).select { |p| p["agency?"] === true }
        expect(wholesale_prices.size).to eq(0)
        wholesale_prices = (book["prices"] || []).select { |p| p["agency?"] === false }
        expect(wholesale_prices.size).to eq(2)
      end

      ["", nil, "en"].each do |code|
        it "must reject a row with invalid currencies: (#{code.class}) #{code.inspect}" do
          row = valid_row(with: { 'Currency Type' => code })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("currency.invalid")
        end
      end
    end

    describe "for page counts" do
      ["143", 143, 143.0].each do |count|
        it "must accept page counts: #{count}" do
          row = valid_row(with: { 'Page Count' => count })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          expect(book["pages"]).to eq(count.to_i)
        end
      end

      ["", nil].each do |count|
        it "must accept empty page counts: #{count.inspect}" do
          row = valid_row(with: { 'Page Count' => count })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          expect(book["pages"]).to be_nil
        end
      end

      ["four hundred", 341.12].each do |count|
        it "must reject a row with non-integer page counts: #{count.inspect}" do
          row = valid_row(with: { 'Page Count' => count })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("page_count.invalid")
          expect(book["pages"]).to be_nil
        end
      end
    end

    describe "for publishers" do
      it "must accept publisher names" do
        publisher = "Awesome Publishing"
        row = valid_row(with: { 'Publisher' => publisher })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect(book["publisher"]).to eq(publisher)
      end

      it "must reject a row with an empty publisher name" do
        publisher = ""
        row = valid_row(with: { 'Publisher' => publisher })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.map { |i| i[:error_code] }).to include("publisher.invalid")
        expect(book["publisher"]).to be_nil
      end
    end

    describe "for BISAC subjects" do
      ["ART015090", "JNF053040", "NON000000"].each do |code|
        it "must accept a row with main BISAC code: #{code}" do
          row = valid_row(with: { 'BISAC Main Subject' => code })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          bisac_codes = book["subjects"].map { |s| s["type"] == "BISAC" ? s["code"] : nil }.compact
          expect(bisac_codes).to include(code)
        end
      end

      ["YXZR", "", nil].each do |not_code|
        it "must reject a row with no or invalid main BISAC subjects: #{not_code.inspect}" do
          row = valid_row(with: { 'BISAC Main Subject' => not_code })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("main_bisac.invalid")
        end
      end

      [",", ", ", ";", "; ", " "].each do |sep|
        it "must accept a row with additional BISAC codes seperated by #{sep.inspect}" do
          codes = ["ART015090", "JNF053040", "NON000000"]
          row = valid_row(with: { 'Additional BISAC Subjects (comma separated)' => codes.join(sep) })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          bisac_codes = book["subjects"].map { |s| s["type"] == "BISAC" ? s["code"] : nil }.compact
          expect(bisac_codes).to include(*codes)
        end
      end

      ["", nil].each do |none|
        it "must accept a row with no additional BISAC subjects: #{none.inspect}" do
          row = valid_row(with: { 'Additional BISAC Subjects (comma separated)' => none })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
        end
      end

      it "must reject a row with invalid additional BISAC subjects" do
        row = valid_row(with: { 'Additional BISAC Subjects (comma separated)' => "YXZZ" })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.map { |i| i[:error_code] }).to include("additional_bisac.invalid")
      end
    end

    describe "for territories" do
      [",", ", ", ";", "; ", " "].each do |sep|
        it "must accept a row with territory codes seperated by #{sep.inspect}" do
          territories = ["GB", "ie", "DE"]
          row = valid_row(with: { 'Territories' => territories.join(sep) })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          regional_rights = Hash[territories.map { |t|
            [t.upcase, true]
          }]
          expect(book["regionalRights"]).to eq(regional_rights)
        end
      end

      it "must accept the WORLD territory" do
        row = valid_row(with: { 'Territories' => "WORLD" })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect(book["regionalRights"]["WORLD"]).to eq(true)
      end

      ["not", "z", "12"].each do |invalid_territory|
        it "must reject the territory #{invalid_territory.inspect}" do
          row = valid_row(with: { 'Territories' => invalid_territory })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("territories.invalid")
        end
      end

      [" ", "", nil].each do |none|
        it "must reject a row with no territories: #{none.inspect}" do
          row = valid_row(with: { 'Territories' => none })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("territories.invalid")
        end
      end
    end

    describe "for descriptions" do
      it "must accept text descriptions" do
        desc = "A general description"
        row = valid_row(with: { 'Description' => desc })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect((book['descriptions'] || []).size).to eq(1)
        expect(book['descriptions'].first['content']).to eq(desc)
      end

      it "must accept and not mangle HTML in descriptions" do
        html = "<p>This is a n <abbr>HTML</abbr> description</p>"
        row = valid_row(with: { 'Description' => html })

        book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
        expect(issues.size).to eq(0)
        expect((book['descriptions'] || []).size).to eq(1)
        expect(book['descriptions'].first['content']).to eq(html)
      end

      ["", nil].each do |none|
        it "must reject empty descriptions: #{none.inspect}" do
          row = valid_row(with: { 'Description' => none })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.map { |i| i[:error_code] }).to include("description.invalid")
        end
      end

      { # Malicious HTML
        "javascript URIs"   => ["<a href=\"javascript:alert('evil');\">javascript uris</a>", "<a>javascript uris</a>"],
        "onlick javascript" => ["<a href=\"nice.html\" onclick=\"alert('evil')\">onclick</a>", "<a href=\"nice.html\">onclick</a>"],
        "iframes"           => ["<iframe src=\"something.html\"></iframe>",""]
      }.each do |name, parts|
        it "must defang #{name} in HTML" do
          html = "<p>Some general html with extra #{parts.first} in the middle</p>"
          clean_html = html.gsub(parts.first, parts.last)
          row = valid_row(with: { 'Description' => html })

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, 0)
          expect(issues.size).to eq(0)
          expect((book['descriptions'] || []).size).to eq(1)
          expect(book['descriptions'].first['content']).to eq(clean_html)
        end
      end
    end

    describe "for issues" do
      invalid_headings.each do |heading, invalid_value|
        it "must include cell references in the issue object for invalid #{heading}" do
          row = valid_row(with: { heading => invalid_value })

          column_num = row.keys.index(heading) + 1
          row_num = 3
          cell_reference = "#{Roo::Base.number_to_letter(column_num)}#{row_num}"

          book, issues = reader.send(:validate_spreadsheet_row_hash, row, row_num)
          expect(issues.size).to be > 0, "An incorrect number of issues was received (#{issues.map{ |i| i["message"] }.join(", ")})"

          expect(issues.first[:data][:row]).to eq(row_num)
          expect(issues.first[:data][:column]).to eq(column_num)
          expect(issues.first[:data][:cell_reference]).to eq(cell_reference)
        end
      end
    end
  end

  describe "#each_book" do
    before :each do 
      @roo = instance_double(Roo::Excel)
      @reader = described_class.allocate

      @reader.instance_variable_set(:'@roo', @roo)
    end

    it "must return one issue and not call the block if headings are not correct" do
      incorrect_headings = ["something", "incorrect"]
      rows = 5
      allow(@roo).to receive(:last_row).and_return(rows)
      allow(@roo).to receive(:row).and_return(incorrect_headings)
      issues = @reader.each_book { |book| expect("this").to be "never run" }
      expect(issues.size).to eq(1)
      expect(issues.first[:error_code]).to eq("headers.incorrect")
    end

    it "must yield to the block for every valid row in a spreadsheet" do
      rows = 5
      book_content = :book
      allow(@roo).to receive(:last_row).and_return(rows)
      allow(@roo).to receive(:row).and_return(Blinkbox::SpreadsheetProcessor::Reader::REQUIRED_HEADINGS)
      allow(@reader).to receive(:validate_spreadsheet_row_hash).and_return([book_content, []])
      
      called = 0
      @reader.each_book do |book|
        called += 1
        expect(book).to eql(book_content), "The method yielded something which wasn't the book"
      end
      expect(called).to eq(rows - 1) # One for the header
    end

    it "must return failures in processing from the block" do
      rows = 5
      one_issue = [:issues]
      allow(@roo).to receive(:last_row).and_return(rows)
      allow(@roo).to receive(:row).and_return(Blinkbox::SpreadsheetProcessor::Reader::REQUIRED_HEADINGS)
      allow(@reader).to receive(:validate_spreadsheet_row_hash).and_return([{}, one_issue])
      issues = @reader.each_book { |book| }
      expected_issues = one_issue * (rows - 1)
      expect(issues).to eq(expected_issues)
    end
  end
end