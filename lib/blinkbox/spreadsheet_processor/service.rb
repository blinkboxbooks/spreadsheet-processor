require "blinkbox/common_messaging"
require "blinkbox/common_logging"
require "blinkbox/mappings"

module Blinkbox
  module SpreadsheetProcessor
    class Service
      attr_reader :logger

      def initialize(options)
        # @logger = CommonLogging.from_config(options.tree(:logging))
        @logger = Logger.new(STDOUT)
        # @logger.facility_version = VERSION
        @service_name = options[:'logging.gelf.facility']

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
        @logger.debug "Spreadsheet Processor v#{VERSION} initialized"
      end

      def start
        @queue.subscribe do |metadata, obj|
          case obj
          when CommonMessaging::IngestionFilePendingV2
            process_spreadsheet(metadata, obj)
            :ack
          else
            @logger.error "Unexpected message in the queue (#{obj.content_type}; id: #{metadata[:message_id]}). Sent to DLQ."
            :reject
          end
        end
      end

      def join

      end

      def stop

      end

      private

      def process_spreadsheet(metadata, obj)
        downloaded_file_io = @mapper.open(obj['source']['uri'])
        begin
          reader = Reader.new(downloaded_file_io.path)
          source = obj['source'].merge(
            'system' => {
              'name' => @service_name,
              'version' => VERSION
            }
          )
          issues = reader.each_book do |book|
            book['classification'] = [
              {
                realm: "isbn",
                id: book[:isbn]
              },
              {
                realm: "source_username",
                id: source['username']
              }
            ]
            book[:source] = source
            book_obj = CommonMessaging::IngestionBookMetadataV2.new(book)

            @exchange.publish(book_obj)
            # TODO: Proper log message
            @logger.info "Book #{book['isbn']} has been published"
          end

          if issues.any?
            rej_obj = CommonMessaging::IngestionFileRejectedV2.new(
              # TODO: Format of rejection reasons
              rejectionReasons: issues,
              source: source
            )

            @exchange.publish(rej_obj)
            # TODO: Proper error message
            @logger.info "Issues were found with a file: #{issues.join(", ")}"
          end
        ensure
          downloaded_file_io.close
          downloaded_file_io.unlink
        end
      end
    end
  end
end