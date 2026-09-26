# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The class_level_routing plugin adds routing methods at the class level, which can
    # be used instead of or in addition to using the normal +route+ method to start the
    # routing tree.  If a request is not matched by the normal routing tree, the class
    # level routes will be tried.  This offers a more Sinatra-like API, while
    # still allowing you to use a routing tree inside individual actions.
    #
    # Here's the first example from the README, modified to use the class_level_routing
    # plugin:
    #
    #   class App < Roda
    #     plugin :class_level_routing
    #
    #     # GET / request
    #     root do
    #       request.redirect "/hello"
    #     end
    #
    #     # GET /hello/world request
    #     get "hello/world" do
    #       "Hello world!"
    #     end
    #
    #     # /hello request
    #     is "hello" do
    #       # Set variable for both GET and POST requests
    #       @greeting = 'Hello'
    #
    #       # GET /hello request
    #       request.get do
    #         "#{@greeting}!"
    #       end
    #
    #       # POST /hello request
    #       request.post do
    #         puts "Someone said #{@greeting}!"
    #         request.redirect
    #       end
    #     end
    #   end
    #
    # When using the class_level_routing plugin with nested routes, you may also want to use the
    # delegate plugin to delegate certain instance methods to the request object, so you don't have
    # to continually use +request.+ in your routing blocks.
    #
    # Note that class level routing is implemented via a simple array of routes, so routing performance
    # will degrade linearly as the number of routes increases.  For best performance, you should use
    # the normal +route+ class method to define your routing tree.  This plugin does make it simpler to
    # add additional routes after the routing tree has already been defined, though.
    module ClassLevelRouting
      # Initialize the class_routes array when the plugin is loaded.  Also, if the application doesn't
      # currently have a routing block, setup an empty routing block so that things will still work if
      # a routing block isn't added.
      def self.configure(app)
        app.opts[:class_level_routes] ||= []
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :class_level_routes)

        # Define routing methods that will store class level routes.
        [:root, :on, :is, :get, :post, :delete, :head, :options, :link, :patch, :put, :trace, :unlink].each do |request_meth|
          define_method(request_meth) do |*args, &block|
            meth = define_roda_method("class_level_routing_#{request_meth}", :any, &block)
            class_level_routes << [request_meth, args, meth].freeze
          end
        end

        # Freeze the class level routes so that there can be no thread safety issues at runtime.
        def freeze
          class_level_routes.freeze
          super
        end
      end

      module InstanceMethods
        def initialize(_)
          super
          @_original_remaining_path = @_request.remaining_path
        end

        private

        # If the normal routing tree doesn't handle an action, try each class level route
        # to see if it matches.
        def _roda_after_10__class_level_routing(result)
          if result && result[0] == 404 && (v = result[2]).is_a?(Array) && v.empty?
            # Reset the response so it doesn't inherit the status or any headers from
            # the original response.
            @_response.send(:initialize)
            @_response.status = nil
            result.replace(_roda_handle_route do
              r = @_request
              self.class.class_level_routes.each do |request_meth, args, meth|
                r.instance_variable_set(:@remaining_path, @_original_remaining_path)
                r.public_send(request_meth, *args) do |*a|
                  send(meth, *a)
                end
              end
              nil
            end)
          end
        end
      end
    end

    register_plugin(:class_level_routing, ClassLevelRouting)
  end
end
