require "blinkbox/common_config"
require "blinkbox/spreadsheet_processor/service"

context Blinkbox::SpreadsheetProcessor::Service do
  describe "#intialize" do
    before :each do
      @options = Blinkbox::CommonConfig.new
    end

    it "must create pending assets & mapping updates queues if they are not present" do
      queue = stub_const("Blinkbox::CommonMessaging::Queue", double(Blinkbox::CommonMessaging::Queue))
      allow(queue).to receive(:new)
      described_class.new(@options)
      expect(queue).to have_received(:new).with("Marvin.spreadsheet_processor.pending_assets", exchange: "Marvin", bindings: anything)
    end

    it "must create a mapping updates queue if they are not present" do
      pending "Mapping isn't defined fully yet"
      queue = stub_const("Blinkbox::CommonMessaging::Queue", double(Blinkbox::CommonMessaging::Queue))
      allow(queue).to receive(:new)
      described_class.new(@options)
      expect(queue).to have_received(:new).with("Marvin.spreadsheet_processor.mapping_updates", exchange: "Mapping", bindings: anything)
    end

    it "must not start if logging options are missing" do
      opts = double(@options)
      allow(opts).to receive(:tree).with(:logging).and_return({})
      expect {
        described_class.new(opts)
      }.to raise_error(ArgumentError)
    end
  end

  describe "#start" do
    before :each do
      @service = described_class.allocate
      allow(@service).to receive(:process_spreadsheet)
      @queue = instance_double(Blinkbox::CommonMessaging::Queue)
      def @queue.subscribe(&block)
        @subscribe_block = block
      end
      @service.instance_variable_set(:'@queue', @queue)

      @logger = instance_double(Blinkbox::CommonLogging)
      @service.instance_variable_set(:'@logger', @logger)
      allow(@logger).to receive(:error)
      @service.start
    end

    def fake_publish(metadata, obj)
      @queue.instance_variable_get(:'@subscribe_block').call(metadata, obj)
    end

    it "must send IngestionFilePendingV2 messages for spreadsheet processing" do
      metadata = {}
      obj = Blinkbox::CommonMessaging::IngestionFilePendingV2.allocate
      expect(fake_publish(metadata, obj)).to eq(:ack)
      expect(@service).to have_received(:process_spreadsheet).with(metadata, obj)
    end

    it "must log an error and reject other messages" do
      metadata = {}
      obj = Blinkbox::CommonMessaging::IngestionBookMetadataV2.allocate
      expect(fake_publish(metadata, obj)).to eq(:reject)
      expect(@service).to_not have_received(:process_spreadsheet).with(metadata, obj)
      expect(@logger).to have_received(:error)
    end
  end

  describe "#process_spreadsheet" do
    it "must accept a file pending v2 object pointing to a spreadsheet and publish a book metadata object for each valid book"
    it "must accept publish one file rejected object if there are any invalid books"
  end
end