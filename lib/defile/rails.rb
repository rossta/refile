require "defile"

module Defile
  module Controller
    include ActionController::Live

    def show
      file = Defile.backends.fetch(params[:backend_name]).get(params[:id])

      response.headers['Content-Disposition'] = "inline"
      response.headers['Content-Length'] = file.size
      if params[:format]
        response.headers['Content-Type'] = Mime::Type.lookup_by_extension(params[:format]).to_s
      end

      until file.eof?
        result = file.read(Defile.read_chunk_size)
        response.stream.write(result)
      end
    ensure
      response.stream.close
      file.close
    end
  end

  class Engine < Rails::Engine
    initializer "defile.setup_backend" do
      Defile.store = Defile::Backend::FileSystem.new(Rails.root.join("tmp/uploads/store").to_s)
      Defile.cache = Defile::Backend::FileSystem.new(Rails.root.join("tmp/uploads/cache").to_s)
    end

    initializer "defile.active_record" do
      ActiveSupport.on_load :active_record do
        require "defile/attachment/active_record"
      end
    end
  end
end
