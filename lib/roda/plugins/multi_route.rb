# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The multi_route plugin builds on the named_routes plugin and allows for
    # dispatching to multiple named routes # by calling the +r.multi_route+ method,
    # which will check # if the first segment in the path matches a named route,
    # and dispatch to that named route.
    #
    # The hash_branches plugin offers a +r.hash_branches+ method that is similar to
    # and performs better than the +r.multi_route+ method, and it is recommended
    # to consider using that instead of this plugin.
    #
    # Example:
    #
    #   plugin :multi_route
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
    #     r.multi_route
    #   end
    #
    # Note that only named routes with string names will be dispatched to by the
    # +r.multi_route+ method. Named routes with other names can be dispatched to
    # using the named_routes plugin API, but will not be automatically dispatched
    # to by +r.multi_route+.
    #
    # You can provide a block to +r.multi_route+ that is
    # called if the route matches but the named route did not handle the
    # request:
    #
    #   r.multi_route do
    #     "default body"
    #   end
    # 
    # If a block is not provided to multi_route, the return value of the named
    # route block will be used.
    #
    # == Namespace Support
    #
    # The multi_route plugin also has support for namespaces, allowing you to
    # use +r.multi_route+ at multiple levels in your routing tree.  Example:
    #
    #   route('foo') do |r|
    #     r.multi_route('foo')
    #   end
    #
    #   route('bar') do |r|
    #     r.multi_route('bar')
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
    #     r.multi_route
    #   end
    module MultiRoute
      def self.load_dependencies(app)
        app.plugin :named_routes
      end

      # Initialize storage for the named routes.
      def self.configure(app)
        app::RodaRequest.instance_variable_set(:@namespaced_route_regexps, {})
      end

      module ClassMethods
        # Freeze the multi_route regexp matchers so that there can be no thread safety issues at runtime.
        def freeze
          super
          namespaced_routes.each_key do |k|
            self::RodaRequest.named_route_regexp(k)
          end
          self::RodaRequest.instance_variable_get(:@namespaced_route_regexps).freeze
          self
        end

        # Copy the named routes into the subclass when inheriting.
        def inherited(subclass)
          super
          subclass::RodaRequest.instance_variable_set(:@namespaced_route_regexps, {})
        end

        # Clear the multi_route regexp matcher for the namespace.
        def route(name=nil, namespace=nil, &block)
          super
          if name
            self::RodaRequest.clear_named_route_regexp!(namespace)
          end
        end
      end

      module RequestClassMethods
        # Clear cached regexp for named routes, it will be regenerated
        # the next time it is needed.
        #
        # This shouldn't be an issue in production applications, but
        # during development it's useful to support new named routes
        # being added while the application is running.
        def clear_named_route_regexp!(namespace=nil)
          @namespaced_route_regexps.delete(namespace)
        end

        # A regexp matching any of the current named routes.
        def named_route_regexp(namespace=nil)
          @namespaced_route_regexps[namespace] ||= /(#{Regexp.union(roda_class.named_routes(namespace).select{|s| s.is_a?(String)}.sort.reverse)})/
        end
      end

      module RequestMethods
        # Check if the first segment in the path matches any of the current
        # named routes.  If so, call that named route.  If not, do nothing.
        # If the named route does not handle the request, and a block
        # is given, yield to the block.
        def multi_route(namespace=nil)
          on self.class.named_route_regexp(namespace) do |section|
            res = route(section, namespace)
            if defined?(yield)
              yield
            else
              res
            end
          end
        end
      end
    end

    register_plugin(:multi_route, MultiRoute)
  end
end
