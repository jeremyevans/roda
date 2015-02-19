class Roda
  module RodaPlugins
    # The padrino_render plugin adds rendering support that is
    # similar to Padrino's.  While not everything Padrino's
    # rendering supports is supported by this plugin (yet), it
    # currently handles enough to be a drop in replacement for
    # some applications.
    #
    # Most notably, this makes the +render+ method default to
    # using the layout, similar to how the +view+ method works
    # in the render plugin.  If you want to call render and not
    # use a layout, you can use the <tt>:layout=>false</tt>
    # option:
    #
    #   render('test')                 # layout
    #   render('test', :layout=>false) # no layout
    #
    # This also adds a +partial+ method, which renders templates
    # without the layout, but prefixes the template filename to
    # use with an underscore:
    #
    #   partial('test')     # uses _test.erb
    #   partial('dir/test') # uses dir/_test.erb
    #
    #
    module PadrinoRender
      OPTS  = {}.freeze
      SLASH = '/'.freeze

      # Depend on the render plugin, since this overrides
      # some of its methods.
      def self.load_dependencies(app, opts=OPTS)
        app.plugin :render, opts
      end

      module InstanceMethods
        # Call view with the given arguments, so that render
        # uses a layout by default.
        def render(template, opts=OPTS)
          view(template, opts)
        end

        # Renders the given template without a layout, but
        # prefixes the template filename to use with an
        # underscore.
        def partial(template, opts=OPTS)
          opts = parse_template_opts(template, opts)
          if opts[:template]
            template        = opts[:template].split(SLASH)
            template[-1]    = "_#{template[-1]}"
            opts[:template] = template.join(SLASH)
          end
          render_template(opts)
        end
      end
    end

    register_plugin(:padrino_render, PadrinoRender)
  end
end
