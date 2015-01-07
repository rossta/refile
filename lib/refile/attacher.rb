require "open-uri"

module Refile
  # @api private
  class Attacher
    attr_reader :record, :name, :cache, :store, :cache_id, :options, :errors, :type, :valid_extensions, :valid_content_types
    attr_accessor :remove

    def initialize(record, name, cache:, store:, raise_errors: true, type: nil, extension: nil, content_type: nil)
      @record = record
      @name = name
      @raise_errors = raise_errors
      @cache = Refile.backends.fetch(cache.to_s)
      @store = Refile.backends.fetch(store.to_s)
      @type = type
      @valid_extensions = [extension].flatten if extension
      @valid_content_types = [content_type].flatten if content_type
      @valid_content_types ||= Refile.types.fetch(type).content_type if type
      @errors = []
    end

    def id
      read(:id)
    end

    def size
      read(:size)
    end

    def filename
      read(:filename)
    end

    def content_type
      read(:content_type)
    end

    def basename
      ::File.basename(filename, "." << extension)
    end

    def extension
      ::File.extname(filename).sub(/^\./, "") if filename
    end

    def data
      if valid?
        { content_type: content_type, filename: filename, size: size, id: cache_id }
      end
    end

    def get
      if cached?
        cache.get(cache_id)
      elsif id and not id == ""
        store.get(id)
      end
    end

    def set(value)
      if value.is_a?(String)
        retrieve!(value)
      else
        cache!(value)
      end
    end

    def retrieve!(value)
      data = JSON.parse(value, symbolize_names: true)
      @cache_id = data.delete(:id)
      write_metadata(**data) if @cache_id
    rescue JSON::ParserError
    end

    def cache!(uploadable)
      write_metadata(
        size: uploadable.size,
        content_type: Refile.extract_content_type(uploadable),
        filename: Refile.extract_filename(uploadable)
      )
      if valid?
        @cache_id = cache.upload(uploadable).id
      elsif @raise_errors
        raise Refile::Invalid, @errors.join(", ")
      end
    end

    def download(url)
      if url and not url == ""
        file = open(url)
        write_metadata(
          size: file.meta["content-length"].to_i,
          filename: ::File.basename(file.base_uri.path),
          content_type: file.meta["content-type"]
        )
        @cache_id = cache.upload(file).id if valid?
      end
    rescue OpenURI::HTTPError, RuntimeError => error
      raise if error.is_a?(RuntimeError) and error.message !~ /redirection loop/
      @errors = [:download_failed]
      raise if @raise_errors
    end

    def store!
      if remove?
        delete!
      elsif cached?
        file = store.upload(cache.get(cache_id))
        delete!(write: false)
        write(:id, file.id)
      end
    end

    def delete!(write: true)
      if cached?
        cache.delete(cache_id)
        @cache_id = nil
      end
      store.delete(id) if id
      write(:id, nil)
      write_metadata if write
    end

    def accept
      if valid_content_types
        valid_content_types.join(",")
      elsif valid_extensions
        valid_extensions.map { |e| ".#{e}" }.join(",")
      end
    end

    def remove?
      remove and remove != "" and remove !~ /\A0|false$\z/
    end

    def valid?
      @errors = []
      @errors << :invalid_extension if valid_extensions and not valid_extensions.include?(extension)
      @errors << :invalid_content_type if valid_content_types and not valid_content_types.include?(content_type)
      @errors << :too_large if cache.max_size and size and size >= cache.max_size
      @errors.empty?
    end

  private

    def read(column)
      value = instance_variable_get(:"@#{column}")
      m = "#{name}_#{column}"
      value ||= record.send(m) if record.respond_to?(m)
      value
    end

    def write(column, value)
      instance_variable_set(:"@#{column}", value)
      m = "#{name}_#{column}="
      record.send(m, value) if record.respond_to?(m) and not record.frozen?
    end

    def write_metadata(size: nil, content_type: nil, filename: nil)
      write(:size, size)
      write(:content_type, content_type)
      write(:filename, filename)
    end

    def cached?
      cache_id and not cache_id == ""
    end
  end
end
