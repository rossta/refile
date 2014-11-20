require "fileutils"

module Defile
  class << self
    attr_accessor :read_chunk_size
    attr_writer :store, :cache

    def backends
      @backends ||= {}
    end

    def store
      backends["store"]
    end

    def store=(backend)
      backends["store"] = backend
    end

    def cache
      backends["cache"]
    end

    def cache=(backend)
      backends["cache"] = backend
    end

    def configure
      yield self
    end

    def verify_uploadable(uploadable)
      [:size, :read, :eof?, :close].each do |m|
        unless uploadable.respond_to?(m)
          raise ArgumentError, "does not respond to `#{m}`."
        end
      end
      true
    end
  end

  require "defile/version"
  require "defile/attachment"
  require "defile/random_hasher"
  require "defile/file"
  require "defile/backend/file_system"
end

Defile.configure do |config|
  config.read_chunk_size = 50000
end
