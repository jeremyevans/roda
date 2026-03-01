# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The host_authorization plugin allows configuring an authorized host or
    # an array of authorized hosts.  Then in the routing tree, you can check
    # whether the request uses an authorized host via the +check_host_authorization!+
    # method.
    # 
    # If the request doesn't match one of the authorized hosts, the
    # request processing stops at that point. Using this plugin can prevent
    # DNS rebinding attacks if the application can receive requests for
    # arbitrary hosts.
    #
    # By default, an empty response using status 403 will be returned for requests
    # with unauthorized hosts.
    #
    # Because +check_host_authorization!+ is an instance method, you can easily choose
    # to only check for authorization in certain routes, or to check it after
    # other processing.  For example, you could check for authorized hosts after
    # serving static files, since the serving of static files should not be
    # vulnerable to DNS rebinding attacks.
    #
    # = Usage
    #
    # In your routing tree, call the +check_host_authorization!+ method at the point you
    # want to check for authorized hosts:
    #
    #   plugin :host_authorization, 'www.example.com'
    #   plugin :public
    #
    #   route do |r|
    #    r.public
    #    check_host_authorization!
    #
    #    # ...
    #   end
    #
    # = Specifying authorized hosts
    #
    # For applications hosted on a single domain name, you can use a single string:
    #
    #   plugin :host_authorization, 'www.example.com'
    #
    # For applications hosted on multiple domain names, you can use an array of strings:
    #
    #   plugin :host_authorization, %w'www.example.com www.example2.com'
    #
    # For applications supporting arbitrary subdomains, you can use a regexp. If using
    # a regexp, make sure you use <tt>\A<tt> and <tt>\z</tt> in your regexp, and restrict
    # the allowed characters to the minimum required, otherwise you can potentionally
    # introduce a security issue:
    #
    #   plugin :host_authorization, /\A[-0-9a-f]+\.example\.com\z/
    #
    # For applications with more complex requirements, you can use a proc.  Similarly
    # to the regexp case, the proc should be aware the host contains user-submitted
    # values, and not assume it is in any particular format:
    #
    #   plugin :host_authorization, proc{|host| ExternalService.allowed_host?(host)}
    #
    # If an array of values is passed as the host argument, the host is authorized if
    # it matches any value in the array.  All host authorization checks use the
    # <tt>===</tt> method, which is why it works for strings, regexps, and procs.
    # It can also work with arbitrary objects that support <tt>===</tt>.
    #
    # For security reasons, only the +Host+ header is checked by default.  If you are
    # sure that your application is being run behind a forwarding proxy that sets the
    # <tt>X-Forwarded-Host</tt> header, you should enable support for checking that
    # header using the +:check_forwarded+ option:
    # 
    #   plugin :host_authorization, 'www.example.com', check_forwarded: true
    #
    # In this case, the trailing host in the <tt>X-Forwarded-Host</tt> header is checked,
    # which should be the host set by the forwarding proxy closest to the application.
    # In cases where multiple forwarding proxies are used that append to the
    # <tt>X-Forwarded-Host</tt> header, you should not use this plugin.
    #
    # = Customizing behavior
    #
    # By default, an unauthorized host will receive an empty 403 response.  You can
    # customize this by passing a block when loading the plugin. For example, for
    # sites using the render plugin, you could return a page that uses your default
    # layout:
    #
    #   plugin :render
    #   plugin :host_authorization, 'www.example.com' do |r|
    #     response.status = 403
    #     view(:content=>"<h1>Forbidden</h1>")
    #   end
    #
    # The block passed to this plugin is treated as a match block.
    module HostAuthorization
      def self.configure(app, host, opts=OPTS, &block)
        app.opts[:host_authorization_host] = host
        app.opts[:host_authorization_check_forwarded] = opts[:check_forwarded] if opts.key?(:check_forwarded)

        if block
          app.define_roda_method(:host_authorization_unauthorized, 1, &block)
        end
      end

      module InstanceMethods
        # Check whether the host is authorized.  If not authorized, return a response
        # immediately based on the plugin block.
        def check_host_authorization!
          r = @_request
          return if host_authorized?(_convert_host_for_authorization(r.env["HTTP_HOST"].to_s.dup))

          if opts[:host_authorization_check_forwarded] && (host = r.env["HTTP_X_FORWARDED_HOST"])
            if i = host.rindex(',')
              host = host[i+1, 10000000].to_s
            end
            host = _convert_host_for_authorization(host.strip)

            if !host.empty? && host_authorized?(host)
              return
            end
          end

          r.on do
            host_authorization_unauthorized(r)
          end
        end

        private

        # Remove the port information from the passed string (mutates the passed argument).
        def _convert_host_for_authorization(host)
          host.sub!(/:\d+\z/, "")
          host
        end

        # Whether the host given is one of the authorized hosts for this application.
        def host_authorized?(host, authorized_host = opts[:host_authorization_host])
          case authorized_host
          when Array
            authorized_host.any?{|auth_host| host_authorized?(host, auth_host)}
          else
            authorized_host === host
          end
        end

        # Action to take for unauthorized hosts. Sets a 403 status by default.
        def host_authorization_unauthorized(_)
          @_response.status = 403
          nil
        end
      end
    end

    register_plugin(:host_authorization, HostAuthorization)
  end
end
