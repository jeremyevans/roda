# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The hash_branches plugin allows for O(1) dispatch to multiple route tree branches,
    # based on the next segment in the remaining path:
    #
    #   class App < Roda
    #     plugin :hash_branches
    #
    #     hash_branch("a") do |r|
    #       # /a branch
    #     end
    #
    #     hash_branch("b") do |r|
    #       # /b branch
    #     end
    #
    #     route do |r|
    #       r.hash_branches
    #     end
    #   end
    #
    # With the above routing tree, the +r.hash_branches+ call in the main routing tree
    # will dispatch requests for the +/a+ and +/b+ branches of the tree to the appropriate
    # routing blocks.
    #
    # In this example, the hash branches for +/a+ and +/b+ are in the same file, but in larger
    # applications, they are usually stored in separate files.  This allows for easily splitting
    # up the routing tree into a separate file per branch.
    #
    # The +hash_branch+ method supports namespaces, which allow for dispatching to sub-branches
    # any level of the routing tree, fully supporting the needs of applications with large and
    # deep routing branches:
    #
    #   class App < Roda
    #     plugin :hash_branches
    #
    #     # Only one argument used, so the namespace defaults to '', and the argument
    #     # specifies the route name
    #     hash_branch("a") do |r|
    #       # No argument given, so uses the already matched path as the namespace,
    #       # which is '/a' in this case.
    #       r.hash_branches
    #     end
    #
    #     hash_branch("b") do |r|
    #       # uses :b as the namespace when looking up routes, as that was explicitly specified
    #       r.hash_branches(:b)
    #     end
    #
    #     # Two arguments used, so first specifies the namespace and the second specifies
    #     # the branch name
    #     hash_branch("/a", "b") do |r|
    #       # /a/b path
    #     end
    #
    #     hash_branch("/a", "c") do |r|
    #       # /a/c path 
    #     end
    #
    #     hash_branch(:b, "b") do |r|
    #       # /b/b path
    #     end
    #
    #     hash_branch(:b, "c") do |r|
    #       # /b/c path 
    #     end
    #
    #     route do |r|
    #       # No argument given, so uses '' as the namespace, as no part of the path has
    #       # been matched yet
    #       r.hash_branches
    #     end
    #   end
    #
    # With the above routing tree, requests for the +/a+ and +/b+ branches will be
    # dispatched to the appropriate +hash_branch+ block.  Those blocks will the dispatch
    # to the remaining +hash_branch+ blocks, with the +/a+ branch using the implicit namespace of
    # +/a+, and the +/b+ branch using the explicit namespace of +:b+.
    #
    # It is best for performance to explicitly specify the namespace when calling
    # +r.hash_branches+.
    module HashBranches
      def self.configure(app)
        app.opts[:hash_branches] ||= {}
      end

      module ClassMethods
        # Freeze the hash_branches metadata when freezing the app.
        def freeze
          opts[:hash_branches].freeze.each_value(&:freeze)
          super
        end

        # Duplicate hash_branches metadata in subclass.
        def inherited(subclass)
          super

          h = subclass.opts[:hash_branches]
          opts[:hash_branches].each do |namespace, routes|
            h[namespace] = routes.dup
          end
        end

        # Add branch handler for the given namespace and segment. If called without
        # a block, removes the existing branch handler if it exists.
        def hash_branch(namespace='', segment, &block)
          segment = "/#{segment}"
          routes = opts[:hash_branches][namespace] ||= {}
          if block
            routes[segment] = define_roda_method(routes[segment] || "hash_branch_#{namespace}_#{segment}", 1, &convert_route_block(block))
          elsif meth = routes.delete(segment)
            remove_method(meth)
          end
        end
      end

      module RequestMethods
        # Checks the matching hash_branch namespace for a branch matching the next
        # segment in the remaining path, and dispatch to that block if there is one.
        def hash_branches(namespace=matched_path)
          rp = @remaining_path

          return unless rp.getbyte(0) == 47 # "/"

          if routes = roda_class.opts[:hash_branches][namespace]
            if segment_end = rp.index('/', 1)
              if meth = routes[rp[0, segment_end]]
                always do
                  @remaining_path = rp[segment_end, 100000000]
                  scope.send(meth, self)
                end
              end
            elsif meth = routes[rp]
              always do
                @remaining_path = ''
                scope.send(meth, self)
              end
            end
          end
        end
      end
    end

    register_plugin(:hash_branches, HashBranches)
  end
end
