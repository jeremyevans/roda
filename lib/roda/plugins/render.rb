require "tilt"

class Roda
  module RodaPlugins
    # The render plugin adds support for template rendering using the tilt
    # library.  Two methods are provided for template rendering, +view+
    # (which uses the layout) and +render+ (which does not).
    #
    #   plugin :render
    #
    #   route do |r|
    #     r.is 'foo' do
    #       view('foo') # renders views/foo.erb inside views/layout.erb
    #     end
    #
    #     r.is 'bar' do
    #       render('bar') # renders views/bar.erb
    #     end
    #   end
    #
    # You can provide options to the plugin method:
    #
    #   plugin :render, :engine=>'haml', :views=>'admin_views'
    #
    # The following options are supported:
    #
    # :cache :: nil/false to not cache templates (useful for development), defaults
    #           to true unless RACK_ENV is development to automatically use the
    #           default template cache.
    # :engine :: The tilt engine to use for rendering, defaults to 'erb'.
    # :escape :: Use Roda's Erubis escaping support, which makes <tt><%= %></tt> escape output,
    #            <tt><%== %></tt> not escape output, and handles postfix conditions inside
    #            <tt><%= %></tt> tags.
    # :ext :: The file extension to assume for view files, defaults to the :engine
    #         option.
    # :layout :: The base name of the layout file, defaults to 'layout'.
    # :layout_opts :: The options to use when rendering the layout, if different
    #                 from the default options.
    # :template_opts :: The tilt options used when rendering templates, defaults to
    #                   <tt>{:outvar=>'@_out_buf', :default_encoding=>Encoding.default_external}</tt>.
    # :views :: The directory holding the view files, defaults to 'views' in the
    #           current directory.
    #
    # Most of these options can be overridden at runtime by passing options
    # to the +view+ or +render+ methods:
    #
    #   view('foo', :ext=>'html.erb')
    #   render('foo', :views=>'admin_views')
    #
    # There are a couple of additional options to +view+ and +render+ that are
    # available at runtime:
    #
    # :content :: Only respected by +view+, provides the content to render
    #             inside the layout, instead of rendering a template to get
    #             the content.
    # :inline :: Use the value given as the template code, instead of looking
    #            for template code in a file.
    # :locals :: Hash of local variables to make available inside the template.
    # :path :: Use the value given as the full pathname for the file, instead
    #          of using the :views and :ext option in combination with the
    #          template name.
    # :template :: Provides the name of the template to use.  This allows you
    #              pass a single options hash to the render/view method, while
    #              still allowing you to specify the template name.
    # :template_block :: Pass this block when creating the underlying template,
    #                    ignored when using :inline.
    # :template_class :: Provides the template class to use, inside of using
    #                    Tilt or <tt>Tilt[:engine]</tt>.
    #
    # Here's how those options are used:
    #
    #   view(:inline=>'<%= @foo %>')
    #   render(:path=>'/path/to/template.erb')
    #
    # If you pass a hash as the first argument to +view+ or +render+, it should
    # have either +:template+, +:inline+, +:path+, or +:content+ (for +view+) as
    # one of the keys.
    module Render
      OPTS={}.freeze

      def self.load_dependencies(app, opts=OPTS)
        if opts[:escape]
          app.plugin :_erubis_escaping
        end
      end

      # Setup default rendering options.  See Render for details.
      def self.configure(app, opts=OPTS)
        orig_opts = opts
        if app.opts[:render]
          app.opts[:render] = app.opts[:render].merge(opts)
        else
          app.opts[:render] = opts.dup
        end

        opts = app.opts[:render]
        opts[:engine]     ||= "erb"
        opts[:ext]          = nil unless opts.has_key?(:ext)
        opts[:views]      ||= File.expand_path("views", Dir.pwd)
        opts[:layout_opts]  = (opts[:layout_opts] || {}).dup

        if layout = orig_opts.fetch(:layout, true)
          opts[:layout] = true unless opts.has_key?(:layout)

          case layout
          when Hash
            opts[:layout_opts].merge!(layout)
          when true
            opts[:layout_opts][:template] ||= 'layout'
          else
            opts[:layout_opts][:template] = layout
          end
        end

        template_opts = opts[:template_opts] = (opts[:template_opts] || {}).dup
        template_opts[:outvar] ||= '@_out_buf'
        if RUBY_VERSION >= "1.9" && !template_opts.has_key?(:default_encoding)
          template_opts[:default_encoding] = Encoding.default_external
        end
        if opts[:escape]
          template_opts[:engine_class] = ErubisEscaping::Eruby
        end
        opts[:cache] = app.thread_safe_cache if opts.fetch(:cache, ENV['RACK_ENV'] != 'development')
        opts[:layout_opts].freeze
        opts[:template_opts].freeze
        opts.freeze
      end

      module ClassMethods
        # Copy the rendering options into the subclass, duping
        # them as necessary to prevent changes in the subclass
        # affecting the parent class.
        def inherited(subclass)
          super
          opts = subclass.opts[:render] = subclass.opts[:render].dup
          opts[:cache] = thread_safe_cache if opts[:cache]
          opts.freeze
        end

        # Return the render options for this class.
        def render_opts
          opts[:render]
        end
      end

      module InstanceMethods
        # Render the given template. See Render for details.
        def render(template, opts = OPTS, &block)
          opts = find_template(parse_template_opts(template, opts))
          cached_template(opts) do
            template_opts         = render_opts[:template_opts]
            current_template_opts = opts[:template_opts]
            template_opts         = template_opts.merge(current_template_opts) if current_template_opts
            opts[:template_class].new(opts[:path], 1, template_opts, &opts[:template_block])
          end.render(self, (opts[:locals]||OPTS), &block)
        end

        # Return the render options for the instance's class. While this
        # is not currently frozen, it may be frozen in a future version,
        # so you should not attempt to modify it.
        def render_opts
          self.class.render_opts
        end

        # Render the given template.  If there is a default layout
        # for the class, take the result of the template rendering
        # and render it inside the layout.  See Render for details.
        def view(template, opts=OPTS)
          opts = parse_template_opts(template, opts)
          content = opts[:content] || render_template(opts)

          if layout_opts  = view_layout_opts(opts)
            content = render_template(layout_opts){content}
          end

          content
        end

        private

        # Private alias for render.  Should be used by other plugins when they want to render a template
        # without a layout, as plugins can override render to use a layout.
        alias render_template render

        # If caching templates, attempt to retrieve the template from the cache.  Otherwise, just yield
        # to get the template.
        def cached_template(opts, &block)
          if cache = render_opts[:cache]
            key = opts[:key]
            unless template = cache[key]
              template = cache[key] = yield
            end
            template
          else
            yield
          end
        end

        # Given the template name and options, return the template class, template path/content,
        # and template block to use for the render.
        def find_template(opts)
          if content = opts[:inline]
            path                  = opts[:path] = content
            template_class        = opts[:template_class] ||= ::Tilt[opts[:engine] || render_opts[:engine]]
            opts[:template_block] = Proc.new{content}
          else
            path                    = opts[:path] ||= template_path(opts)
            template_class          = opts[:template_class]
            opts[:template_class] ||= ::Tilt
          end

          if render_opts[:cache]
            template_opts = opts[:template_opts]
            template_block = opts[:template_block] if !content

            key = if template_class || template_opts || template_block
              [path, template_class, template_opts, template_block]
            else
              path
            end
            opts[:key] = key
          end

          opts
        end

        # Return a single hash combining the template and opts arguments.
        def parse_template_opts(template, opts)
          template = {:template=>template} unless template.is_a?(Hash)
          opts.merge(template)
        end

        # The name to use for the template.  By default, just converts the :template option to a string.
        def template_name(opts)
          opts[:template].to_s
        end

        # The template path for the given options.
        def template_path(opts)
          render_opts = render_opts()
          "#{opts[:views] || render_opts[:views]}/#{template_name(opts)}.#{opts[:ext] || render_opts[:ext] || render_opts[:engine]}"
        end

        # If a layout should be used, return a hash of options for
        # rendering the layout template.  If a layout should not be
        # used, return nil.
        def view_layout_opts(opts)
          if layout = opts.fetch(:layout, render_opts[:layout])
            layout_opts = if opts[:layout_opts]
              opts[:layout_opts].merge(render_opts[:layout_opts])
            else
              render_opts[:layout_opts].dup
            end

            case layout
            when Hash
              layout_opts.merge!(layout)
            when true
              # use default layout
            else
              layout_opts[:template] = layout
            end

            layout_opts
          end
        end

      end
    end

    register_plugin(:render, Render)
  end
end
