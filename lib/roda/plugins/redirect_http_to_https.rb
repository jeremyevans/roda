# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The redirect_http_to_https plugin exposes a +redirect_http_to_https+
    # request method that redirects HTTP requests to HTTPS, helping to ensure
    # that future requests by the same browser will be submitted securely.
    #
    # You should use this plugin if you have an application that can receive
    # requests using both HTTP and HTTPS, and you want to make sure that all
    # or a subset of routes are only handled for HTTPS requests.
    #
    # The reason this exposes a request method is so that you can choose where
    # in your routing tree to do the redirection:
    #
    #   route do |r|
    #     # routes available via both HTTP and HTTPS
    #     r.redirect_http_to_https
    #     # routes available only via HTTPS
    #   end
    #
    # If you want to redirect to HTTPS for all routes in the routing tree, you
    # can have this as the very first method call in the routing tree.  Note that
    # in Roda it is possible to handle routing before the normal routing tree
    # using before hooks.  The static_routing and heartbeat plugins use this
    # feature. If you would like to handle routes before the normal routing tree,
    # you can setup a before hook:
    #
    #   plugin :hooks
    #
    #   before do
    #     request.redirect_http_to_https
    #   end
    module RedirectHttpToHttps
      status_map = Hash.new(307)
      status_map['GET'] = status_map['HEAD'] = 301
      status_map.freeze
      DEFAULTS = {:status_map => status_map}.freeze
      private_constant :DEFAULTS

      # Configures redirection from HTTP to HTTPS.  Available options:
      #
      # :body :: The body used in the redirect.  If not set, uses an empty body.
      # :headers :: Any additional headers used in the redirect response. By default,
      #             no additional headers are set, the only header used is the Location header.
      # :host :: The host to redirect to.  If not set, redirects to the same host as the HTTP
      #          requested to.  It is highly recommended that you set this if requests with
      #          arbitrary Host headers can be submitted to the application.
      # :port :: The port to use in the redirect.  By default, will not set an explicit port,
      #          so that it will implicitly use the HTTPS default port of 443.
      # :status_map :: A hash mapping request methods to response status codes.  By default,
      #                uses a hash that redirects GET and HEAD requests with a 301 status,
      #                and other request methods with a 307 status.
      def self.configure(app, opts=OPTS)
        opts = app.opts[:redirect_http_to_https] = (app.redirect_http_to_https_opts || DEFAULTS).merge(opts)
        opts[:port_string] = opts[:port] ? ":#{opts[:port]}".freeze : "".freeze
        opts[:prefix] = opts[:host] ? "https://#{opts[:host]}#{opts[:port_string]}".freeze : nil
        opts.freeze
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :redirect_http_to_https, name: :redirect_http_to_https_opts)
      end

      module RequestMethods
        # Redirect HTTP requests to HTTPS. While this doesn't secure the
        # current request, it makes it more likely that the browser will submit
        # future requests securely via HTTPS.
        def redirect_http_to_https
          return if ssl?

          opts = roda_class.redirect_http_to_https_opts

          res = response

          if body = opts[:body]
            res.write(body)
          end

          if headers = opts[:headers]
            res.headers.merge!(headers)
          end

          path = if prefix = opts[:prefix]
            prefix + fullpath
          else
            "https://#{host}#{opts[:port_string]}#{fullpath}"
          end

          unless status = opts[:status_map][@env['REQUEST_METHOD']]
            raise RodaError, "redirect_http_to_https :status_map provided does not support #{@env['REQUEST_METHOD']}"
          end

          redirect(path, status)
        end
      end
    end

    register_plugin(:redirect_http_to_https, RedirectHttpToHttps)
  end
end
