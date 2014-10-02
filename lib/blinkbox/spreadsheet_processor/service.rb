require "blinkbox/spreadsheet_processor/version"
require "blinkbox/common_messaging"
require "blinkbox/common_logging"
require "blinkbox/mappings"
require "blinkbox/spreadsheet_processor/reader"

module Blinkbox
  module SpreadsheetProcessor
    class Service
      attr_reader :logger

      def initialize(options)
        @logger = CommonLogging.from_config(options.tree(:logging))
        @logger.facility_version = VERSION
        @service_name = "Marvin/spreadsheet_processor"
        raise "logging.gelf.facility is not #{@service_name}." unless @service_name == options[:'logging.gelf.facility']

        CommonMessaging.configure!(options.tree(:rabbitmq), @logger)

        schema_root = File.join(__dir__, "../../../schemas")
        schema_files = File.join(schema_root, "ingestion")
        CommonMessaging.init_from_schema_at(schema_files, schema_root).each do |klass|
          @logger.debug "Loaded schema file for #{klass::CONTENT_TYPE}"
        end

        file_found_content_types = [
          "application/vnd.ms-excel",
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        ]

        bindings = file_found_content_types.map do |content_type|
          {
            "content-type" => "application/vnd.blinkbox.books.ingestion.file.pending.v2+json",
            "referenced-content-type" => content_type,
            "x-match" => "all"
          }
        end

        @queue = CommonMessaging::Queue.new(
          "#{@service_name.tr('/','.')}.pending_assets",
          exchange: "Marvin",
          bindings: bindings
        )

        @exchange = CommonMessaging::Exchange.new(
          "Marvin",
          facility: @service_name,
          facility_version: VERSION
        )

        @mapper = Mappings.new(
          options[:'mapper.url'],
          service_name: @service_name
        )
        @logger.info "Spreadsheet Processor v#{VERSION} initialized"
      end

      def start
        @queue.subscribe do |metadata, obj|
          case obj
          when CommonMessaging::IngestionFilePendingV2
            process_spreadsheet(metadata, obj)
            :ack
          else
            @logger.error(
              short_message: "Unexpected message in the queue",
              message_id: metadata[:message_id],
              data: {
                object_class: obj.class,
                object_as_string: obj.to_s,
                object: obj,
                object_content_type: (obj.content_type rescue "n/a")
              }
            )
            :reject
          end
        end
      end

      def stop

      end

      private

      def process_spreadsheet(metadata, obj)
        downloaded_file_io = @mapper.open(obj['source']['uri'])
        begin
          source = obj['source'].merge(
            'system' => {
              'name' => @service_name,
              'version' => VERSION
            }
          )
          reader = Reader.new(downloaded_file_io.path, source['contentType'])
          issues = reader.each_book do |book|
            book['classification'] = [
              {
                'realm' => "isbn",
                'id' => book['isbn']
              },
              {
                'realm' => "source_username",
                'id' => source['username']
              }
            ]
            book['source'] = source
            # TODO: move this to the common messgaing library?
            book['$schema'] = 'ingestion.book.metadata.v2'
            book_obj = CommonMessaging::IngestionBookMetadataV2.new(book)

            # TODO: Add extra bits to common messaging that type:remote uris trigger the correct header
            message_id = @exchange.publish(book_obj)
            @logger.info(
              short_message: "Details for book #{book['isbn']} have been published",
              isbn: book['isbn'],
              message_id: message_id,
              data: {
                source: source.dup
              }
            )
          end

          if issues.any?
            rej_obj = CommonMessaging::IngestionFileRejectedV2.new(
              rejectionReasons: issues,
              source: source
            )

            message_id = @exchange.publish(rej_obj)
            # TODO: Proper error message
            @logger.info(
              short_message: "Issues were found with formatting of a spreadsheet",
              message_id: message_id,
              data: {
                source: source.dup,
                issues: issues
              }
            )
          end
        ensure
          downloaded_file_io.close
          downloaded_file_io.unlink if downloaded_file_io.respond_to? :unlink
        end
      end
    end
  end
end