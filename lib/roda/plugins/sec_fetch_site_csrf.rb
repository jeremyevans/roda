# frozen-string-literal: true

class Roda
  module RodaPlugins
    # The sec_fetch_site plugin allows for CSRF protection using the
    # Sec-Fetch-Site header added in modern browsers. It allows for CSRF
    # protection without the use of CSRF tokens, which can simplify
    # form creation.
    #
    # The protection offered by the sec_fetch_site plugin is weaker than
    # the protection offered by the route_csrf plugin with default settings,
    # since it doesn't support per-request tokens. Be aware you are trading
    # security for simplicity when using the sec_fetch_site plugin instead
    # of the route_csrf plugin.  Other caveats in using the sec_fetch_site
    # plugin:
    #
    # * Not all browsers set the Sec-Fetch-Site header. Some browsers
    #   didn't start setting the header until 2023. In these cases, you
    #   need to decide how to handle the request. The default is to deny
    #   the request, though you can use the :allow_missing option to allow
    #   it.
    #
    # * Sec-Fetch-Site headers are not set for http requests, only https
    #   requests, so this doesn't offer protection for http requests.
    #
    # * It isn't possible to share a CSRF secret between applications in
    #   different origins to allow cross-site requests between the
    #   applications.
    #
    # This plugin adds the +check_sec_fetch_site!+ method to the routing
    # block scope. You should call this method at the appropriate place
    # in the routing tree to enforce the CSRF protection. The method can
    # accept a block to override the :csrf_failure plugin option behavior
    # on a per-call basis.
    #
    # When loading the plugin with no options:
    #
    #   plugin :sec_fetch_site_csrf
    #
    # Only same-origin requests are allowed by default.
    #
    # This plugin supports the following options:
    #
    # :allow_missing :: Whether to allow requests lacking the Sec-Fetch-Site
    #                   header (false by default).
    # :allow_none :: Whether to allow requests where Sec-Fetch-Value is none
    #                (false by default).
    # :allow_same_site :: Whether to allow requests where Sec-Fetch-Value is
    #                     same-site (false by default)
    # :check_request_methods :: Which request methods require CSRF protection
    #                           (default: <tt>['POST', 'DELETE', 'PATCH', 'PUT']</tt>)
    # :csrf_failure :: The action to taken if a request does not have a valid header
    #                  (default: :raise).  Options:
    #                  :raise :: raise a Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
    #                            exception
    #                  :empty_403 :: return a blank 403 page
    #                  :clear_session :: clear the current session
    #
    # The plugin also supports a block, in which case failures will call the block
    # as a routing block (the block should accept the request object).
    module SecFetchSiteCsrf
      DEFAULTS = {
        :csrf_failure => :raise,
        :check_request_methods => %w'POST DELETE PATCH PUT'.freeze.each(&:freeze)
      }.freeze

      # Exception class raised when :csrf_failure option is :raise and
      # the Sec-Fetch-Site header is not considered valid.
      class CsrfFailure < RodaError; end

      def self.configure(app, opts=OPTS, &block)
        options = app.opts[:sec_fetch_site_csrf] = (app.opts[:sec_fetch_site_csrf] || DEFAULTS).merge(opts)

        allowed_values = options[:allowed_values] = ["same-origin"]
        allowed_values << "same-site" if opts[:allow_same_site]
        allowed_values << "none" if opts[:allow_none]
        allowed_values << nil if opts[:allow_missing]
        allowed_values.freeze

        if block
          options[:csrf_failure] = :method
          app.define_roda_method(:_roda_sec_fetch_site_csrf_failure, 1, &app.send(:convert_route_block, block))
        end

        case options[:csrf_failure]
        when :raise, :empty_403, :clear_session, :method
          # nothing
        else
          raise RodaError, "Unsupported :csrf_failure plugin option: #{options[:csrf_failure].inspect}"
        end

        options.freeze
      end

      module InstanceMethods
        # Check that the Sec-Fetch-Site header is valid, if the request requires it.
        # If the header is valid or the request does not require the header, return nil.
        # Otherwise, if a block is given, treat it as a routing block and yield to it, and
        # if a block is not given, use the plugin :csrf_failure option to determine how to
        # handle it.
        def check_sec_fetch_site!(&block)
          plugin_opts = self.class.opts[:sec_fetch_site_csrf]
          return unless plugin_opts[:check_request_methods].include?(request.request_method)

          sec_fetch_site = env["HTTP_SEC_FETCH_SITE"]
          return if plugin_opts[:allowed_values].include?(sec_fetch_site)

          @_request.on(&block) if block
          
          case failure_action = plugin_opts[:csrf_failure]
          when :raise
            raise CsrfFailure, "potential cross-site request, Sec-Fetch-Site value: #{sec_fetch_site.inspect}"
          when :empty_403
            @_response.status = 403
            headers = @_response.headers
            headers.clear
            headers[RodaResponseHeaders::CONTENT_TYPE] = 'text/html'
            headers[RodaResponseHeaders::CONTENT_LENGTH] ='0'
            throw :halt, @_response.finish_with_body([])
          when :clear_session
            session.clear
          else # when :method
            @_request.on{_roda_sec_fetch_site_csrf_failure(@_request)}
          end
        end
      end
    end

    register_plugin(:sec_fetch_site_csrf, SecFetchSiteCsrf)
  end
end
