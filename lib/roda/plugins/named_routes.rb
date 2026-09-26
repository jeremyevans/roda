# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The named_routes plugin allows for multiple named routes, which the
    # main route block can dispatch to by name at any point by calling +r.route+.
    # If the named route doesn't handle the request, execution will continue,
    # and if the named route does handle the request, the response returned by
    # the named route will be returned.
    #
    # Example:
    #
    #   plugin :named_routes
    #
    #   route('foo') do |r|
    #     r.is 'bar' do
    #       '/foo/bar'
    #     end
    #   end
    #
    #   route('bar') do |r|
    #     r.is 'foo' do
    #       '/bar/foo'
    #     end
    #   end
    #
    #   route do |r|
    #     r.on "foo" do
    #       r.route 'foo'
    #     end
    #
    #     r.on "bar" do
    #       r.route 'bar'
    #     end
    #   end
    #
    # Note that in multi-threaded code, you should not attempt to add a
    # named route after accepting requests.
    #
    # To handle development environments that reload code, you can call the
    # +route+ class method without a block to remove an existing named route.
    #
    # == Routing Files
    #
    # The convention when using the named_routes plugin is to have a single
    # named route per file, and these routing files should be stored in
    # a routes subdirectory in your application.  So for the above example, you
    # would use the following files:
    #
    #   routes/bar.rb
    #   routes/foo.rb
    #
    # == Namespace Support
    #
    # The named_routes plugin also has support for namespaces, allowing you to
    # use +r.route+ at multiple levels in your routing tree.  Example:
    #
    #   route('foo') do |r|
    #     r.on("baz"){r.route("baz", "foo")}
    #     r.on("quux"){r.route("quux", "foo")}
    #   end
    #
    #   route('bar') do |r|
    #     r.on("baz"){r.route("baz", "bar")}
    #     r.on("quux"){r.route("quux", "bar")}
    #   end
    #
    #   route('baz', 'foo') do |r|
    #     # handles /foo/baz prefix
    #   end
    #
    #   route('quux', 'foo') do |r|
    #     # handles /foo/quux prefix
    #   end
    #
    #   route('baz', 'bar') do |r|
    #     # handles /bar/baz prefix
    #   end
    #
    #   route('quux', 'bar') do |r|
    #     # handles /bar/quux prefix
    #   end
    #
    #   route do |r|
    #     r.on "foo" do
    #       r.route("foo")
    #     end
    #
    #     r.on "bar" do
    #       r.route("bar")
    #     end
    #   end
    #
    # === Routing Files
    #
    # The convention when using namespaces with the multi_route plugin is to
    # store the routing files in subdirectories per namespace. So for the
    # above example, you would have the following routing files:
    #
    #   routes/bar.rb
    #   routes/bar/baz.rb
    #   routes/bar/quux.rb
    #   routes/foo.rb
    #   routes/foo/baz.rb
    #   routes/foo/quux.rb
    module NamedRoutes
      # Initialize storage for the named routes.
      def self.configure(app)
        app.opts[:namespaced_routes] ||= {}
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :namespaced_routes)

        # Freeze the namespaced routes so that there can be no thread safety issues at runtime.
        def freeze
          namespaced_routes.freeze.each_value(&:freeze)
          super
        end

        # Copy the named routes into the subclass when inheriting.
        def inherited(subclass)
          super
          nsr = subclass.namespaced_routes
          namespaced_routes.each{|k, v| nsr[k] = v.dup}
        end

        # The names for the currently stored named routes
        def named_routes(namespace=nil)
          unless routes = namespaced_routes[namespace]
            raise RodaError, "unsupported named_routes namespace used: #{namespace.inspect}"
          end
          routes.keys
        end

        # Return the named route with the given name.
        def named_route(name, namespace=nil)
          namespaced_routes[namespace][name]
        end

        # If the given route has a name, treat it as a named route and
        # store the route block.  Otherwise, this is the main route, so
        # call super.
        def route(name=nil, namespace=nil, &block)
          if name
            routes = namespaced_routes[namespace] ||= {}
            if block
              routes[name] = define_roda_method(routes[name] || "named_routes_#{namespace}_#{name}", 1, &convert_route_block(block))
            elsif meth = routes.delete(name)
              remove_method(meth)
            end
          else
            super(&block)
          end
        end
      end

      module RequestMethods
        # Dispatch to the named route with the given name.
        def route(name, namespace=nil)
          scope.send(roda_class.named_route(name, namespace), self)
        end
      end
    end

    register_plugin(:named_routes, NamedRoutes)
  end
end
