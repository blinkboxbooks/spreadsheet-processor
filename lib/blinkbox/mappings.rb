# FIXME: This is a mock file for use while the quartermaster is being created
require "uri"

module Blinkbox
  class Mappings
    def initialize(_, _ = {})

    end

    # We assume that everything is mapped to /mnt/ for the mocking purposes
    def open(mapped_uri)
      uri = URI(mapped_uri)
      location = File.join("/mnt", uri.hostname, uri.path)

      if block_given?
        File.open(location) do |f|
          yield f
        end
      else
        io = File.open(location)

        def io.unlink
          # Do nothing
        end

        io
      end
    end
  end
end
