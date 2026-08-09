# frozen-string-literal: true

# RODA4: Remove plugin

require 'rack/csrf'

class Roda
  module RodaPlugins
    # This plugin is no longer recommended for use, it exists only for
    # backwards compatibility.  Consider using the route_csrf plugin
    # instead, as that provides stronger CSRF protection.
    # This plugin will no longer ship with Roda starting in Roda 4.
    #
    # The csrf plugin adds CSRF protection using rack_csrf, along with
    # some csrf helper methods to use in your views.  To use it, load
    # the plugin, with the options hash passed to Rack::Csrf:
    #
    #   plugin :csrf, raise: true
    #
    # Optionally you can choose not to setup rack_csrf middleware on the
    # roda app if you already have one configured:
    #
    #   plugin :csrf, skip_middleware: true
    #
    # This adds the following instance methods:
    #
    # csrf_field :: The field name to use for the hidden/meta csrf tag.
    # csrf_header :: The http header name to use for submitting csrf token via
    #                headers (useful for javascript).
    # csrf_metatag :: An html meta tag string containing the token, suitable
    #                 for placing in the page header
    # csrf_tag :: An html hidden input tag string containing the token, suitable
    #             for placing in an html form.
    # csrf_token :: The value of the csrf token, in case it needs to be accessed
    #               directly.
    module Csrf
      CSRF = ::Rack::Csrf

      # Load the Rack::Csrf middleware into the app with the given options.
      def self.configure(app, opts={})
        return if opts[:skip_middleware]
        app.instance_exec do
          @middleware.each do |(mid, *rest), _|
            if mid.equal?(CSRF)
              rest[0].merge!(opts)
              build_rack_app
              return
            end
          end
          use CSRF, opts
        end
      end

      module InstanceMethods
        # The name of the hidden/meta csrf tag.
        def csrf_field
          CSRF.field
        end

        # The http header name to use for submitting csrf token via headers.
        def csrf_header
          CSRF.header
        end

        # An html meta tag string containing the token.
        def csrf_metatag(opts={})
          CSRF.metatag(env, opts)
        end

        # An html hidden input tag string containing the token.
        def csrf_tag
          CSRF.tag(env)
        end

        # The value of the csrf token.
        def csrf_token
          CSRF.token(env)
        end
      end
    end

    register_plugin(:csrf, Csrf)
  end
end
