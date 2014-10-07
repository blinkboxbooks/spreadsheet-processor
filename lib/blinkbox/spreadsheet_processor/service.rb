require "blinkbox/spreadsheet_processor/version"
require "blinkbox/common_messaging"
require "blinkbox/common_logging"
require "blinkbox/common_mapping"
require "blinkbox/tictoc"
require "blinkbox/spreadsheet_processor/reader"

module Blinkbox
  module SpreadsheetProcessor
    class Service
      attr_reader :logger
      include Blinkbox::CommonHelpers::TicToc

      def initialize(options)
        tic
        @logger = CommonLogging.from_config(options.tree(:logging))
        @logger.facility_version = VERSION
        @service_name = "Marvin/spreadsheet_processor"
        raise "logging.gelf.facility is not #{@service_name}." unless @service_name == options[:'logging.gelf.facility']

        CommonMessaging.configure!(options.tree(:rabbitmq), @logger)

        schema_root = File.join(__dir__, "../../../schemas")
        schema_files = File.join(schema_root, "ingestion")
        CommonMessaging.init_from_schema_at(schema_files, schema_root).each do |klass|
          @logger.debug(
            short_message: "Loaded schema file for #{klass::CONTENT_TYPE}",
            event: :dependency_loaded
          )
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

        @mapper = CommonMapping.new(
          options[:'mapper.url'],
          service_name: @service_name
        )
        @logger.info(
          short_message: "Spreadsheet Processor v#{VERSION} initialized",
          event: :service_started,
          duration: toc
        )
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
              event: :message_uninterpretable,
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
        tic
        # What needs to be done here? I need to look into rabbit.
        @logger.info(
          short_message: "Spreadsheet Processor v#{VERSION} shut down",
          event: :service_stopped,
          duration: toc
        )
      end

      private

      def process_spreadsheet(metadata, obj)
        tic :spreadsheet
        @mapper.open(obj['source']['uri']) do |downloaded_file_io|
          source = obj['source'].merge(
            'system' => {
              'name' => @service_name,
              'version' => VERSION
            }
          )
          reader = Reader.new(downloaded_file_io.path, source['contentType'])
          issues = reader.each_book do |book|
            tic :book
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
            message_id = @exchange.publish(book_obj, message_id_chain: metadata[:headers]['message_id_chain'])
            @logger.info(
              short_message: "Details for book #{book['isbn']} have been published",
              event: :book_details_found,
              isbn: book['isbn'],
              message_id: message_id,
              duration: toc(:book),
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

            message_id = @exchange.publish(rej_obj, message_id_chain: metadata[:headers]['message_id_chain'])
            # TODO: Proper error message
            @logger.info(
              short_message: "Issues were found with formatting of a spreadsheet",
              event: :spreadsheet_invalid,
              message_id: message_id,
              data: {
                source: source.dup,
                issues: issues
              }
            )
          end
          @logger.debug(
            short_message: "Spreadsheet processing finished",
            event: :spreadsheet_finished,
            duration: toc(:spreadsheet)
          )
        end
      end
    end
  end
end