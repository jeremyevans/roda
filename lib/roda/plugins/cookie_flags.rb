# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The cookie_flags plugin allows users to force specific cookie flags for
    # all cookies set by the application.  It can also be used to warn or
    # raise for unexpected cookie flags.
    #
    # The cookie_flags plugin deals with the following cookie flags:
    #
    # httponly :: Disallows access to the cookie from client-side scripts.
    # samesite :: Restricts to which domains the cookie is sent.
    # secure :: Instructs the browser to only transmit the cookie over HTTPS.
    #
    # This plugin ships in secure-by-default mode, where it enforces
    # secure, httponly, samesite=strict cookies. You can disable enforcing
    # specific flags using the following options:
    #
    # :httponly :: Set to false to not enforce httponly flag.
    # :same_site :: Set to symbol or string to enforce a different samesite
    #               setting, or false to not enforce a specific samesite setting.
    # :secure :: Set to false to not enforce secure flag.
    #
    # For example, to enforce secure cookies and enforce samesite=lax, but not enforce
    # an httponly flag:
    #
    #   plugin :cookie_flags, httponly: false, same_site: 'lax'
    #
    # In general, overriding cookie flags using this plugin should be considered a
    # stop-gap solution.  Instead of overriding cookie flags, it's better to fix
    # whatever is setting the cookie flags incorrectly.  You can use the :action
    # option to modify the behavior:
    #
    #   # Issue warnings when modifying cookie flags
    #   plugin :cookie_flags, action: :warn_and_modify
    #
    #   # Issue warnings for incorrect cookie flags without modifying cookie flags
    #   plugin :cookie_flags, action: :warn
    #
    #   # Raise errors for incorrect cookie flags
    #   plugin :cookie_flags, action: :raise
    #
    # The recommended way to use the plugin is to use it only during testing with
    # <tt>action: :raise</tt>.  Then as long as you have fully covering tests, you
    # can be sure the cookies set by your application use the correct flags.
    #
    # Note that this plugin only affects cookies set by the application, and does not
    # affect cookies set by middleware the application is using.
    module CookieFlags
      # simplecov:disable
      MATCH_METH = RUBY_VERSION >= '2.4' ? :match? : :match
      # simplecov:enable
      private_constant :MATCH_METH

      DEFAULTS = {:secure=>true, :httponly=>true, :same_site=>'strict', :action=>:modify}.freeze
      private_constant :DEFAULTS

      # Error class raised for action: :raise when incorrect cookie flags are used.
      class Error < RodaError
      end

      def self.configure(app, opts=OPTS)
        previous = app.opts[:cookie_flags] || DEFAULTS
        opts = app.opts[:cookie_flags] = previous.merge(opts)

        case opts[:same_site]
        when String, Symbol
          opts[:same_site] = opts[:same_site].to_s.downcase.freeze
          opts[:same_site_string] = "; samesite=#{opts[:same_site]}".freeze
          opts[:secure] = true if opts[:same_site] == 'none'
        end

        opts.freeze
      end

      module InstanceMethods
        private

        def _handle_cookie_flags_array(cookies)
          opts = self.class.opts[:cookie_flags]
          needs_secure = opts[:secure]
          needs_httponly = opts[:httponly]
          if needs_same_site = opts[:same_site]
            same_site_string = opts[:same_site_string]
            same_site_regexp = /;\s*samesite\s*=\s*(\S+)\s*(?:\z|;)/i
          end
          action = opts[:action]

          cookies.map do |cookie|
            if needs_secure
              add_secure = !/;\s*secure\s*(?:\z|;)/i.send(MATCH_METH, cookie)
            end

            if needs_httponly
              add_httponly = !/;\s*httponly\s*(?:\z|;)/i.send(MATCH_METH, cookie)
            end

            if needs_same_site
              has_same_site = same_site_regexp.match(cookie)
              unless add_same_site = !has_same_site
                update_same_site = needs_same_site != has_same_site[1].downcase
              end
            end

            next cookie unless add_secure || add_httponly || add_same_site || update_same_site

            case action
            when :raise, :warn, :warn_and_modify
              message = "Response contains cookie with unexpected flags: #{cookie.inspect}." \
                   "Expecting the following cookie flags: "\
                   "#{'secure ' if add_secure}#{'httponly ' if add_httponly}#{same_site_string[2..-1] if add_same_site || update_same_site}"

              if action == :raise
                raise Error, message
              else
                warn(message)
                next cookie if action == :warn
              end
            end

            if update_same_site
              cookie = cookie.gsub(same_site_regexp, same_site_string)
            else
              cookie = cookie.dup
              cookie << same_site_string if add_same_site
            end

            cookie << '; secure' if add_secure
            cookie << '; httponly' if add_httponly

            cookie
          end
        end

        if Rack.release >= '3'
          def _handle_cookie_flags(cookies)
            cookies = [cookies] if cookies.is_a?(String)
            _handle_cookie_flags_array(cookies)
          end
        else
          def _handle_cookie_flags(cookie_string)
            _handle_cookie_flags_array(cookie_string.split("\n")).join("\n")
          end
        end

        # Handle cookie flags in response
        def _roda_after_85__cookie_flags(res)
          return unless res && (headers = res[1]) && (value = headers[RodaResponseHeaders::SET_COOKIE])
          headers[RodaResponseHeaders::SET_COOKIE] = _handle_cookie_flags(value)
        end
      end
    end

    register_plugin(:cookie_flags, CookieFlags)
  end
end
