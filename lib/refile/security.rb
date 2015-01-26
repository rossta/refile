module Refile
  class Security
    def initialize(app)
      @app = app
    end

    def call(env)
      if accepts?(env)
        @app.call(env)
      else
        deny
      end
    end

  private

    def secret_token
      Refile.secret_token
    end

    def accepts?(env)
      skip?(env) || verify?(env)
    end

    def deny
      logger.warn "unsigned request prevented by #{self.class}"

      [403, { "Content-Type" => "text/plain;charset=utf-8" }, ["forbidden"]]
    end

    def verify?(env)
      return true unless secret_token

      request = Rack::Request.new(env)

      request.params["sha"] == Refile.sha(request.path)
    end

    def skip?(env)
      %w[OPTIONS POST].include?(env["REQUEST_METHOD"])
    end

    def logger
      Refile.logger
    end
  end
end
