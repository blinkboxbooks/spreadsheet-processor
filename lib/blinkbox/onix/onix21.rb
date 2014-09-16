require 'nokogiri'

module Blinkbox
  class Onix21
    def initialize(hash)
      @hash = hash
    end

    def to_xml
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.ONIXmessage do
          xml.Header do
            xml.MessageNote "Generated from `#{@hash['data_source']['uri'] rescue ''}` by Marvin for blinkbox books"
          end

          xml.Product do
            xml.ProductIdentifier do
              xml.ProductIDType 15
              xml.IDValue @hash['isbn']
            end

            xml.Title do
              xml.TitleType "01"
              xml.TitleText @hash['title'], textcase: "02"
              xml.Subtitle @hash['subtitle'], textcase: "02" if @hash['subtitle']
            end

            (@hash['descriptions'] || []).each do |description|
              xml.OtherText do
                xml.TextTypeCode description['type'] || "01"
                # this is a dumb guess, the ONIX ingestor can be more careful at checking for the format
                xml.TextFormat (description['content'].include?("<") ? "05" : "06")
                xml.Text do
                  # This allows unescaped tags
                  xml << description['content']
                end
              end
            end

            (@hash['contributors'] || []).each_with_index do |contributor,i|
              xml.Contributor do
                xml.SequenceNumber (i + 1)
                xml.ContributorRole contributor['role']
                xml.PersonName contributor['display_name'] if contributor['display_name']
                xml.PersonNameInverted contributor['sort_name'] if contributor['sort_name']
                if !contributor['biography'].nil? && !contributor['biography'].empty?
                  xml.BiographicalNote(textformat: (contributor['biography'].include?("<") ? "05" : "06")) do
                    # This allows unescaped tags
                    xml << contributor['biography']
                  end
                end
              end

              if contributor['image']
                xml.MediaFile do
                  xml.MediaFileTypeCode "04"
                  xml.MediaFileFormatCode "03"
                  xml.MediaFileLinkTypeCode "01"
                  xml.MediaFileLink contributor['image']
                  xml.DownloadCaption contributor['display_name']
                end
              end
            end

            xml.SupplyDetail do
              (@hash['prices'] || []).each do |price|
                xml.Price do
                  xml.PriceTypeCode ((price['includes_tax?'] ? 2 : 1) + (price['agency?'] ? 40 : 0)).to_s.rjust(2,"0")
                  # Decision made by Robert 2013-10-07 15:58 to round prices to 2 dp here. Other currencies requiring
                  # different levels of rounding is an accepted risk

                  price['amount'] = $1.to_f if price['amount'] =~ /^.?(\d+(?:\.\d+)?).?$/
                  raise "Non numeric price: #{price['amount']}" unless price['amount'].is_a?(Numeric)

                  xml.PriceAmount price['amount'].to_f.round(2)
                  xml.CurrencyCode price['currency']
                end
              end
            end

            xml.PublicationDate @hash['dates']['publish'].strftime("%Y%m%d") if (@hash['dates']['publish'] rescue false)
            if @hash['imprint']
              xml.Imprint do
                xml.ImprintName @hash['imprint']
              end
            end

            if @hash['publisher']
              xml.Publisher do
                xml.PublishingRole "01"
                xml.PublisherName @hash['publisher']
              end
            end

            if @hash['sellable_in'].length != 0
              xml.SalesRights do
                xml.SalesRightsType "01"
                xml.RightsCountry @hash['sellable_in'].join(' ')
              end
            end

            xml.Language do
              xml.LanguageRole "01"
              xml.LanguageCode @hash['language'].first
            end

            if @hash['pages']
              xml.Extent do
                xml.ExtentType "00"
                xml.ExtentValue @hash['pages'].to_i
                xml.ExtentUnit "03"
              end
            end

            (@hash['subjects'] || []).each do |subject|
              if subject['main']
                xml.BASICMainSubject subject['code']
              else
                xml.Subject do
                  xml.SubjectSchemeIdentifier "10"
                  xml.SubjectCode subject['code']
                end
              end
            end
          end
        end
      end

      builder.to_xml
    end

    def [](key)
      @hash[key]
    end
  end
end