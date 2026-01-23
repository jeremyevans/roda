# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The bearer_token plugin adds an +r.bearer_token+ method for retrieving
    # a bearer token from the +Authorization+ HTTP header. Bearer tokens will
    # in the authorization header will be recognized as long as they start
    # with the case insensitive string "bearer ".
    module BearerToken
      # :nocov:
      METHOD = RUBY_VERSION >= "2.4" ? :match? : :match
      # :nocov:

      module RequestMethods
        # Return the bearer token for the request if there is one in the
        # authorization HTTP header.
        def bearer_token
          if (auth = @env["HTTP_AUTHORIZATION"]) && auth.send(METHOD, /\Abearer /i)
            auth[7, 100000000]
          end
        end
      end
    end

    register_plugin(:bearer_token, BearerToken)
  end
end
