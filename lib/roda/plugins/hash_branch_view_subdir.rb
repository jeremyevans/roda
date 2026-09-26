# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The hash_branch_view_subdir plugin builds on the hash_branches and view_options
    # plugins, automatically appending a view subdirectory for any matching hash branch
    # taken. In cases where you are using a separate view subdirectory per hash branch,
    # this can result in DRYer code. Example:
    #
    #   plugin :hash_branch_view_subdir
    #
    #   route do |r|
    #     r.hash_branches
    #   end
    #
    #   hash_branch 'foo' do |r|
    #     # view subdirectory here is 'foo'
    #     r.hash_branches('foo')
    #   end
    #
    #   hash_branch 'foo', 'bar' do |r|
    #     # view subdirectory here is 'foo/bar'
    #   end
    module HashBranchViewSubdir
      def self.load_dependencies(app)
        app.plugin :hash_branches
        app.plugin :view_options
      end

      def self.configure(app)
        app.opts[:hash_branch_view_subdir_methods] ||= {}
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :hash_branch_view_subdir_methods)

        # Freeze the hash_branch_view_subdir metadata when freezing the app.
        def freeze
          hash_branch_view_subdir_methods.freeze.each_value(&:freeze)
          super
        end

        # Duplicate hash_branch_view_subdir metadata in subclass.
        def inherited(subclass)
          super

          h = subclass.hash_branch_view_subdir_methods
          hash_branch_view_subdir_methods.each do |namespace, routes|
            h[namespace] = routes.dup
          end
        end

        # Automatically append a view subdirectory for a successful hash_branch route,
        # by modifying the generated method to append the view subdirectory before
        # dispatching to the original block.
        def hash_branch(namespace='', segment, &block)
          meths = hash_branch_view_subdir_methods[namespace] ||= {}

          if block
            meth = meths[segment] = define_roda_method(meths[segment] || "_hash_branch_view_subdir_#{namespace}_#{segment}", 1, &convert_route_block(block))
            super do |*_|
              append_view_subdir(segment)
              send(meth, @_request)
            end
          else
            if meth = meths.delete(segment)
              remove_method(meth)
            end
            super
          end
        end
      end
    end

    register_plugin(:hash_branch_view_subdir, HashBranchViewSubdir)
  end
end
