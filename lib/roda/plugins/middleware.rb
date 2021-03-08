# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The middleware plugin allows the Roda app to be used as
    # rack middleware.
    #
    # In the example below, requests to /mid will return Mid
    # by the Mid middleware, and requests to /app will not be
    # matched by the Mid middleware, so they will be forwarded
    # to App.
    #
    #   class Mid < Roda
    #     plugin :middleware
    #
    #     route do |r|
    #       r.is "mid" do
    #         "Mid"
    #       end
    #     end
    #   end
    #
    #   class App < Roda
    #     use Mid
    #
    #     route do |r|
    #       r.is "app" do
    #         "App"
    #       end
    #     end
    #   end
    #
    #   run App
    #
    # It is possible to use the Roda app as a regular app even when using
    # the middleware plugin.  Using an app as middleware automatically creates
    # a subclass of the app for the middleware.  Because a subclass is automatically
    # created when the app is used as middleware, any configuration of the app
    # should be done before using it as middleware instead of after.
    #
    # You can support configurable middleware by passing a block when loading
    # the plugin:
    #
    #   class Mid < Roda
    #     plugin :middleware do |middleware, *args, &block|
    #       middleware.opts[:middleware_args] = args
    #       block.call(middleware)
    #     end
    #
    #     route do |r|
    #       r.is "mid" do
    #         opts[:middleware_args].join(' ')
    #       end
    #     end
    #   end
    #
    #   class App < Roda
    #     use Mid, :foo, :bar do |middleware|
    #       middleware.opts[:middleware_args] << :baz
    #     end
    #   end
    #
    #   # Request to App for /mid returns
    #   # "foo bar baz"
    module Middleware
      # Configure the middleware plugin.  Options:
      # :env_var :: Set the environment variable to use to indicate to the roda
      #             application that the current request is a middleware request.
      #             You should only need to override this if you are using multiple
      #             roda middleware in the same application.
      # :handle_result :: Callable object that will be called with request environment
      #                   and rack response for all requests passing through the middleware,
      #                   after either the middleware or next app handles the request
      #                   and returns a response.
      def self.configure(app, opts={}, &block)
        app.opts[:middleware_env_var] = opts[:env_var] if opts.has_key?(:env_var)
        app.opts[:middleware_env_var] ||= 'roda.forward_next'
        app.opts[:middleware_configure] = block if block
        app.opts[:middleware_handle_result] = opts[:handle_result]
      end

      # Forwarder instances are what is actually used as middleware.
      class Forwarder
        # Make a subclass of +mid+ to use as the current middleware,
        # and store +app+ as the next middleware to call.
        def initialize(mid, app, *args, &block)
          @mid = mid
          if configure = @mid.opts[:middleware_configure]
            @mid = Class.new(@mid)
            configure.call(@mid, *args, &block)
          elsif block || !args.empty?
            raise RodaError, "cannot provide middleware args or block unless loading middleware plugin with a block"
          end
          @app = app
        end

        # When calling the middleware, first call the current middleware.
        # If this returns a result, return that result directly.  Otherwise,
        # pass handling of the request to the next middleware.
        def call(env)
          res = nil

          call_next = catch(:next) do
            env[@mid.opts[:middleware_env_var]] = true
            res = @mid.call(env)
            false
          end

          if call_next
            res = @app.call(env)
          end

          if handle_result = @mid.opts[:middleware_handle_result]
            handle_result.call(env, res)
          end

          res
        end
      end

      module ClassMethods
        # Create a Forwarder instead of a new instance if a non-Hash is given.
        def new(app, *args, &block)
          if app.is_a?(Hash)
            super
          else
            Forwarder.new(self, app, *args, &block)
          end
        end
      end

      module InstanceMethods
        # Override the route block so that if no route matches, we throw so
        # that the next middleware is called. Old Dispatch API.
        def call(&block)
          super do |r|
            res = instance_exec(r, &block) # call Fallback
            throw :next, true if r.forward_next
            res
          end
        end

        # Override the route block so that if no route matches, we throw so
        # that the next middleware is called.
        def _roda_run_main_route(r)
          res = super
          throw :next, true if r.forward_next
          res
        end
      end

      module RequestMethods
        # Whether to forward the request to the next application.  Set only if
        # this request is being performed for middleware.
        def forward_next
          env[roda_class.opts[:middleware_env_var]]
        end
      end
    end

    register_plugin(:middleware, Middleware)
  end
end
