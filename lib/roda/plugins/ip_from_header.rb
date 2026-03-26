# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The ip_from_header plugin allows for overriding +request.ip+ to return
    # the value contained in a specific header. This is useful when the
    # application is behind a proxy that sets a specific header, especially
    # when the proxy does not use a fixed IP address range. Example showing 
    # usage with Cloudflare:
    #
    #   plugin :ip_from_header, "CF-Connecting-IP"
    #
    # This plugin assumes that if the header is set, it contains a valid IP
    # address, it does not check the format of the header value, just as
    # <tt>Rack::Request#ip</tt> does not check the IP address it returns is
    # actually valid.
    module IPFromHeader
      def self.configure(app, header)
        app.opts[:ip_from_header_env_key] = "HTTP_#{header.upcase.tr('-', '_')}".freeze
      end

      module RequestMethods
        # Return the IP address continained in the configured header, if present.
        # Fallback to the default behavior if not present.
        def ip
          @env[roda_class.opts[:ip_from_header_env_key]] || super
        end
      end
    end

    register_plugin(:ip_from_header, IPFromHeader)
  end
end
