$: << 'lib'
require "blinkbox/common_messaging"

RSpec.configure do |config|
  config.before :all do
    schema_root = File.join(__dir__, "../schemas")
    schema_dir = File.join(schema_root, "ingestion")
    Blinkbox::CommonMessaging.init_from_schema_at(schema_dir, schema_root)
  end
end