# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The branch_locals plugin allows you to override view and layout
    # locals for specific branches and routes.
    #
    #   plugin :render
    #   plugin :render_locals, render: {footer: 'Default'}, layout: {title: 'Main'}
    #   plugin :branch_locals
    #
    #   route do |r|
    #     r.on "users" do
    #       set_layout_locals title: 'Users'
    #       set_view_locals footer: '(c) Roda'
    #     end
    #   end
    #
    # The locals you specify in the set_layout_locals and set_view_locals methods
    # have higher precedence than the render_locals plugin options, but lower precedence
    # than options you directly pass to the view/render methods.
    module BranchLocals
      SCOPE_INSTANCE_VARIABLES = [:@_layout_locals, :@_view_locals].freeze

      # Load the render_locals plugin before this plugin, since this plugin
      # works by overriding methods in the render_locals plugin.
      def self.load_dependencies(app)
        app.plugin :render_locals
      end

      module InstanceMethods
        # Update the default layout locals to use in this branch.
        def set_layout_locals(opts)
          if locals = @_layout_locals
            @_layout_locals = locals.merge(opts)
          else
            @_layout_locals = opts
          end
        end

        # Update the default view locals to use in this branch.
        def set_view_locals(opts)
          if locals = @_view_locals
            @_view_locals = locals.merge(opts)
          else
            @_view_locals = opts
          end
        end

        private

        # Make branch specific view locals override render_locals plugin defaults.
        def render_locals
          locals = super
          if @_view_locals
            locals = Hash[locals].merge!(@_view_locals)
          end
          locals
        end

        # Make branch specific layout locals override render_locals plugin defaults.
        def layout_locals
          locals = super
          if @_layout_locals
            locals = Hash[locals].merge!(@_layout_locals)
          end
          locals
        end
      end
    end

    register_plugin(:branch_locals, BranchLocals)
  end
end

