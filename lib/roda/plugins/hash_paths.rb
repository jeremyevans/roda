# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The hash_paths plugin allows for O(1) dispatch to multiple routes at any point
    # in the routing tree.  It is useful when you have a large number of specific routes
    # to dispatch to at any point in the routing tree.
    #
    # You configure the hash paths to dispatch to using the +hash_path+ class method,
    # specifying the remaining path, with a block to handle that path.  Then you dispatch
    # to the configured paths using +r.hash_paths+:
    #
    #   class App < Roda
    #     plugin :hash_paths
    #
    #     hash_path("/a") do |r|
    #       # /a path
    #     end
    #
    #     hash_path("/a/b") do |r|
    #       # /a/b path 
    #     end
    #
    #     route do |r|
    #       r.hash_paths
    #     end
    #   end
    #
    # With the above routing tree, the +r.hash_paths+ call will dispatch requests for the +/a+ and
    # +/a/b+ request paths.
    #
    # The +hash_path+ class method supports namespaces, which allows +r.hash_paths+ to be used at
    # any level of the routing tree.  Here is an example that uses namespaces for sub-branches:
    #
    #   class App < Roda
    #     plugin :hash_paths
    #
    #     # Two arguments provided, so first argument is the namespace
    #     hash_path("/a", "/b") do |r|
    #       # /a/b path
    #     end
    #
    #     hash_path("/a", "/c") do |r|
    #       # /a/c path 
    #     end
    #
    #     hash_path(:b, "/b") do |r|
    #       # /b/b path
    #     end
    #
    #     hash_path(:b, "/c") do |r|
    #       # /b/c path 
    #     end
    #
    #     route do |r|
    #       r.on 'a' do
    #         # No argument given, so uses the already matched path as the namespace,
    #         # which is '/a' in this case.
    #         r.hash_paths
    #       end
    #
    #       r.on 'b' do
    #         # uses :b as the namespace when looking up routes, as that was explicitly specified
    #         r.hash_paths(:b)
    #       end
    #     end
    #   end
    #
    # With the above routing tree, requests for the +/a+ branch will be handled by the first
    # +r.hash_paths+ call, and requests for the +/b+ branch will be handled by the second
    # +r.hash_paths+ call.  Those will dispatch to the configured hash paths for the +/a+ and
    # +:b+ namespaces.
    #
    # It is best for performance to explicitly specify the namespace when calling
    # +r.hash_paths+.
    module HashPaths
      def self.configure(app)
        app.opts[:hash_paths] ||= {}
      end

      module ClassMethods
        # Freeze the hash_paths metadata when freezing the app.
        def freeze
          opts[:hash_paths].freeze.each_value(&:freeze)
          super
        end

        # Duplicate hash_paths metadata in subclass.
        def inherited(subclass)
          super

          h = subclass.opts[:hash_paths]
          opts[:hash_paths].each do |namespace, routes|
            h[namespace] = routes.dup
          end
        end

        # Add path handler for the given namespace and path. When the
        # r.hash_paths method is called, checks the matching namespace
        # for the full remaining path, and dispatch to that block if
        # there is one.  If called without a block, removes the existing
        # path handler if it exists.
        def hash_path(namespace='', path, &block)
          routes = opts[:hash_paths][namespace] ||= {}
          if block
            routes[path] = define_roda_method(routes[path] || "hash_path_#{namespace}_#{path}", 1, &convert_route_block(block))
          elsif meth = routes.delete(path)
            remove_method(meth)
          end
        end
      end

      module RequestMethods
        # Checks the matching hash_path namespace for a branch matching the 
        # remaining path, and dispatch to that block if there is one.
        def hash_paths(namespace=matched_path)
          if (routes = roda_class.opts[:hash_paths][namespace]) && (meth = routes[@remaining_path])
            always do
              @remaining_path = ''
              scope.send(meth, self)
            end
          end
        end
      end
    end

    register_plugin(:hash_paths, HashPaths)
  end
end
