require 'fileutils'
require 'tmpdir'
require 'stringio'
require 'logger'

$:.unshift(File.dirname(__FILE__) + '/../../lib')
require 'blinkbox/watcher'

# Ensure the real Blinkbox::Events aren't present
Blinkbox.send(:remove_const,:"Events")
# And load the fake one
require './features/support/blinkbox-events-mock'

FileUtils.mkdir_p("/tmp/jp")

# Replace the has_been_processed command, as we can't have sudo in the tests. It's a pain, because we're not testing what will be live
# but this needs to be there to allow the tests to run uncurated
module Blinkbox
	class Watcher
		def has_been_processed(file)
			# We [shouldn't] need to chmod as root:
			`chmod 444 "#{file}"`
		end
	end
end

class FakePublisherDirectory
	attr_reader :dir

	def up
		@dir = Dir.mktmpdir('blinkbox-watcher')
		@log = StringIO.new

		@watcher = Blinkbox::Watcher.new({
			:watch => @dir,
			'logger' => Logger.new(@log)
		})

		@contents = {}
	end

	def down
		FileUtils.rm_rf(@dir)
		@dir = nil
	end
end

World do 
	FakePublisherDirectory.new
end

Before do
	up
	Blinkbox::Events.clear_all
end

After do |scenario|
	if scenario.failed?
    @log.rewind
    $stderr.puts "Logfile entries for this failing scenario:\n#{@log.read}"
  end

	down
end