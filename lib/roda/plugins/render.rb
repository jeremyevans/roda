# frozen-string-literal: true

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
    # The +render+ and +view+ methods just return strings, they do not have
    # side effects (unless the templates themselves have side effects).
    # As Roda uses the routing block return value as the body of the response,
    # in most cases you will call these methods as the last expression in a
    # routing block to have the response body be the result of the template
    # rendering.
    #
    # Because +render+ and +view+ just return strings, you can call them inside
    # templates (i.e. for subtemplates/partials), or multiple times in the
    # same route and combine the results together:
    #
    #   route do |r|
    #     r.is 'foo-bars' do
    #       @bars = Bar.where(:foo).map{|b| render(:bar, locals: {bar: b})}.join
    #       view('foo')
    #     end
    #   end
    #
    # You can provide options to the plugin method:
    #
    #   plugin :render, engine: 'haml', views: 'admin_views'
    #
    # = Plugin Options
    #
    # The following plugin options are supported:
    #
    # :allowed_paths :: Set the template directories to allow.  Attempts to render paths outside
    #                   of these directories will raise an error.  Defaults to the +:views+ option,
    #                   if it is a directory.  For backwards compatibility, if a non-directory is
    #                   given, it will be used as a prefix match. Roda 4 will raise if a non-directory
    #                   is given as an allowed path and +:check_paths+ is true.
    # :assume_fixed_locals :: Set if you are sure all templates in your application use fixed locals
    #                         to allow for additional optimization. This is ignored unless both
    #                         compiled methods and fixed locals are not supported.
    # :cache :: nil/false to explicitly disable permanent template caching.  By default, permanent
    #           template caching is disabled by default if RACK_ENV is development.  When permanent
    #           template caching is disabled, for templates with paths in the file system, the
    #           modification time of the file will be checked on every render, and if it has changed,
    #           a new template will be created for the current content of the file.
    # :cache_class :: A class to use as the template cache instead of the default.
    # :check_paths :: Can be set to false to turn off template path checking.
    # :engine :: The tilt engine to use for rendering, also the default file extension for
    #            templates, defaults to 'erb'.
    # :escape :: Use Erubi as the ERB template engine, and enable escaping by default,
    #            which makes <tt><%= %></tt> escape output and  <tt><%== %></tt> not escape output.
    #            If given, sets the <tt>escape: true</tt> option for all template engines, which
    #            can break some non-ERB template engines.  You can use a string or array of strings
    #            as the value for this option to only set the <tt>escape: true</tt> option for those
    #            specific template engines.
    # :layout :: The base name of the layout file, defaults to 'layout'.  This can be provided as a hash
    #            with the :template or :inline options.
    # :layout_opts :: The options to use when rendering the layout, if different from the default options.
    # :template_opts :: The tilt options used when rendering all templates. defaults to:
    #                   <tt>{outvar: '@_out_buf', default_encoding: Encoding.default_external}</tt>.
    # :engine_opts :: The tilt options to use per template engine.  Keys are
    #                 engine strings, values are hashes of template options.
    # :views :: The directory holding the view files, defaults to the 'views' subdirectory of the
    #           application's :root option (the process's working directory by default).
    #
    # = Render/View Method Options
    #
    # Most of these options can be overridden at runtime by passing options
    # to the +view+ or +render+ methods:
    #
    #   view('foo', engine: 'html.erb')
    #   render('foo', views: 'admin_views')
    #
    # There are additional options to +view+ and +render+ that are
    # available at runtime:
    #
    # :cache :: Set to false to not cache this template, even when
    #           caching is on by default.  Set to true to force caching for
    #           this template, even when the default is to not permantently cache (e.g.
    #           when using the :template_block option).
    # :cache_key :: Explicitly set the hash key to use when caching.
    # :content :: Only respected by +view+, provides the content to render
    #             inside the layout, instead of rendering a template to get
    #             the content.
    # :inline :: Use the value given as the template code, instead of looking
    #            for template code in a file.
    # :locals :: Hash of local variables to make available inside the template.
    # :path :: Use the value given as the full pathname for the file, instead
    #          of using the :views and :engine option in combination with the
    #          template name.
    # :scope :: The object in which context to evaluate the template.  By
    #           default, this is the Roda instance.
    # :template :: Provides the name of the template to use.  This allows you
    #              pass a single options hash to the render/view method, while
    #              still allowing you to specify the template name.
    # :template_block :: Pass this block when creating the underlying template,
    #                    ignored when using :inline.  Disables caching of the
    #                    template by default.
    # :template_class :: Provides the template class to use, instead of using
    #                    Tilt or <tt>Tilt[:engine]</tt>.
    #
    # Here's an example of using these options:
    #
    #   view(inline: '<%= @foo %>')
    #   render(path: '/path/to/template.erb')
    #
    # If you pass a hash as the first argument to +view+ or +render+, it should
    # have either +:template+, +:inline+, +:path+, or +:content+ (for +view+) as
    # one of the keys.
    #
    # = Fixed Locals in Templates
    #
    # By default, you can pass any local variables to any templates.  A separate
    # template method is compiled for each combination of locals.  This causes
    # multiple issues:
    # 
    # * It is inefficient, especially for large templates that are called with
    #   many combinations of locals.
    # * It hides issues if unused local variable names are passed to the template
    # * It does not support default values for local variables
    # * It does not support required local variables
    # * It does not support cases where you want to pass values via a keyword splat
    # * It does not support named blocks
    #
    # If you are using Tilt 2.6+, you can used fixed locals in templates, by
    # passing the appropriate options in :template_opts.  For example, if you
    # are using ERB templates, the recommended way to use the render plugin is to
    # use the +:extract_fixed_locals+ and +:default_fixed_locals+ template options:
    #
    #   plugin :render, template_opts: {extract_fixed_locals: true, default_fixed_locals: '()'}
    #
    # This will default templates to not allowing any local variables to be passed.
    # If the template requires local variables, you can specify them using a magic
    # comment in the template, such as:
    # 
    #   <%# locals(required_local:, optional_local: nil) %>
    #
    # The magic comment is used as method parameters when defining the compiled template
    # method.
    #
    # For better debugging of issues with invalid keywords being passed to templates that
    # have not been updated to support fixed locals, it can be helpful to set
    # +:default_fixed_locals+ to use a single optional keyword argument
    # <tt>'(_no_kw: nil)'</tt>.  This makes the error message show which keywords
    # were passed, instead of showing that the takes no arguments (if you use <tt>'()'</tt>),
    # or that no keywords are accepted (if you pass <tt>(**nil)</tt>).
    #
    # If you are sure your application works with all templates using fixed locals,
    # set the :assume_fixed_locals render plugin option, which will allow the plugin
    # to optimize cache lookup for renders with locals, and avoid duplicate compiled
    # methods for templates rendered both with and without locals.
    #
    # See Tilt's documentation for more information regarding fixed locals.
    #
    # = Speeding Up Template Rendering
    #
    # The render/view method calls are optimized for usage with a single symbol/string
    # argument specifying the template name.  So for fastest rendering, pass only a
    # symbol/string to render/view.  Next best optimized are template calls with a
    # single :locals option.  Use of other options disables the compiled template
    # method optimizations and can be significantly slower.
    #
    # If you must pass a hash to render/view, either as a second argument or as the
    # only argument, you can speed things up by specifying a +:cache_key+ option in
    # the hash, making sure the +:cache_key+ is unique to the template you are
    # rendering.
    #
    # = Recommended +template_opts+
    #
    # Here are the recommended values of :template_opts for new applications (a couple
    # are Erubi-specific and can be ignored if you are using other templates engines):
    #
    #   plugin :render, 
    #     assume_fixed_locals: true,    # Optimize plugin by assuming all templates use fixed locals
    #     template_opts: {
    #       scope_class: self,          # Always uses current class as scope class for compiled templates
    #       freeze: true,               # Freeze string literals in templates
    #       extract_fixed_locals: true, # Support fixed locals in templates
    #       default_fixed_locals: '()', # Default to templates not supporting local variables
    #       escape: true,               # For Erubi templates, escapes <%= by default (use <%== for unescaped
    #       chain_appends: true,        # For Erubi templates, improves performance
    #       skip_compiled_encoding_detection: true, # Unless you need encodings explicitly specified
    #     }
    #
    # = Accepting Template Blocks in Methods
    #
    # If you are used to Rails, you may be surprised that this type of template code
    # doesn't work in Roda:
    #
    #   <%= some_method do %>
    #     Some HTML
    #   <% end %>
    #
    # The reason this doesn't work is that this is not valid ERB syntax, it is Rails syntax,
    # and requires attempting to parse the <tt>some_method do</tt> Ruby code with a regular
    # expression.  Since Roda uses ERB syntax, it does not support this.
    #
    # In general, these methods are used to wrap the content of the block and
    # inject the content into the output. To get similar behavior with Roda, you have
    # a few different options you can use.
    #
    # == Use Erubi::CaptureBlockEngine
    #
    # Roda defaults to using Erubi for erb template rendering.  Erubi 1.13.0+ includes
    # support for an erb variant that supports blocks in <tt><%=</tt> and <tt><%==</tt>
    # tags.  To use it:
    #
    #   require 'erubi/capture_block'
    #   plugin :render, template_opts: {engine_class: Erubi::CaptureBlockEngine}
    #
    # See the Erubi documentation for how to capture data inside the block.  Make sure
    # the method call (+some_method+ in the example) returns the output you want added
    # to the rendered body.
    #
    # == Directly Inject Template Output
    #
    # You can switch from a <tt><%=</tt> tag to using a <tt><%</tt> tag:
    #
    #   <% some_method do %>
    #     Some HTML
    #   <% end %>
    #
    # While this would output <tt>Some HTML</tt> into the template, it would not be able
    # to inject content before or after the block.  However, you can use the inject_erb_plugin
    # to handle the injection:
    #
    #   def some_method
    #     inject_erb "content before block"
    #     yield
    #     inject_erb "content after block"
    #   end
    #
    # If you need to modify the captured block before injecting it, you can use the
    # capture_erb plugin to capture content from the template block, and modify that content,
    # then use inject_erb to inject it into the template output:
    #
    #   def some_method(&block)
    #     inject_erb "content before block"
    #     inject_erb capture_erb(&block).upcase
    #     inject_erb "content after block"
    #   end
    #
    # This is the recommended approach for handling this type of method, if you want to keep
    # the template block in the same template.
    #
    # == Separate Block Output Into Separate Template
    #
    # By moving the <tt>Some HTML</tt> into a separate template, you can render that
    # template inside the block:
    #
    #  <%= some_method{render('template_name')} %>
    #
    # It's also possible to use an inline template:
    #
    #   <%= some_method do render(:inline=><<-END)
    #     Some HTML
    #     END
    #   end %>
    #
    # This approach is useful if it makes sense to separate the template block into its
    # own template. You lose the ability to use local variable from outside the
    # template block inside the template block with this approach.
    #
    # == Separate Header and Footer
    #
    # You can define two separate methods, one that outputs the content before the block,
    # and one that outputs the content after the block, and use those instead of a single
    # call:
    #
    #   <%= some_method_before %>
    #     Some HTML
    #   <%= some_method_after %>
    #
    # This is the simplest option to setup, but it is fairly tedious to use.
    module Render
      # Support for using compiled methods directly requires Ruby 2.3 for the
      # method binding to work, and Tilt 1.2 for Tilt::Template#compiled_method.
      tilt_compiled_method_support = defined?(Tilt::VERSION) && Tilt::VERSION >= '1.2' &&
        ([1, -2].include?(((compiled_method_arity = Tilt::Template.instance_method(:compiled_method).arity) rescue false)))
      NO_CACHE = {:cache=>false}.freeze
      COMPILED_METHOD_SUPPORT = RUBY_VERSION >= '2.3' && tilt_compiled_method_support && ENV['RODA_RENDER_COMPILED_METHOD_SUPPORT'] != 'no'
      FIXED_LOCALS_COMPILED_METHOD_SUPPORT = COMPILED_METHOD_SUPPORT && Tilt::Template.method_defined?(:fixed_locals?)

      if FIXED_LOCALS_COMPILED_METHOD_SUPPORT
        def self.tilt_template_fixed_locals?(template)
          template.fixed_locals?
        end
      # simplecov:disable
      else
        def self.tilt_template_fixed_locals?(template)
          false
        end
      end
      # simplecov:enable

      if compiled_method_arity == -2
        def self.tilt_template_compiled_method(template, locals_keys, scope_class)
          template.send(:compiled_method, locals_keys, scope_class)
        end
      # simplecov:disable
      else
        def self.tilt_template_compiled_method(template, locals_keys, scope_class)
          template.send(:compiled_method, locals_keys)
        end
      # simplecov:enable
      end

      # Setup default rendering options.  See Render for details.
      def self.configure(app, opts=OPTS)
        if app.opts[:render]
          orig_cache = app.opts[:render][:cache]
          orig_method_cache = app.opts[:render][:template_method_cache]
          opts = app.opts[:render][:orig_opts].merge(opts)
        end
        app.opts[:render] = opts.dup
        app.opts[:render][:orig_opts] = opts

        opts = app.opts[:render]
        opts[:engine] = (opts[:engine] || "erb").dup.freeze
        opts[:views] = app.expand_path(opts[:views]||"views").freeze
        opts[:check_paths] = true unless opts.has_key?(:check_paths)
        opts[:allowed_paths] ||= [opts[:views]]
        opts[:allowed_paths] = opts[:allowed_paths].map do |f|
          path = app.expand_path(f, nil)
          if File.directory?(path) || f == opts[:views]
            path << "/"
          elsif opts[:check_paths]
            # RODA4: raise
            RodaPlugins.warn("allowed path #{f.inspect} is not a directory in the file system. For backwards compatibility, will allow prefix matches, but this could result in security issues. Roda 4 will raise if an allowed path is not a directory.")
          end
          path.freeze
        end.uniq.freeze
        opts[:assume_fixed_locals] &&= FIXED_LOCALS_COMPILED_METHOD_SUPPORT

        unless opts.has_key?(:check_template_mtime)
          opts[:check_template_mtime] = if opts[:cache] == false || opts[:explicit_cache]
            true
          else
            ENV['RACK_ENV'] == 'development'
          end
        end

        begin
          app.const_get(:RodaCompiledTemplates, false)
        rescue NameError
          compiled_templates_module = Module.new
          app.send(:include, compiled_templates_module)
          app.const_set(:RodaCompiledTemplates, compiled_templates_module)
        end
        opts[:template_method_cache] = orig_method_cache || (opts[:cache_class] || RodaCache).new
        opts[:template_method_cache][:_roda_layout] = nil if opts[:template_method_cache][:_roda_layout]
        opts[:cache] = orig_cache || (opts[:cache_class] || RodaCache).new

        opts[:layout_opts] = (opts[:layout_opts] || {}).dup
        opts[:layout_opts][:_is_layout] = true
        if opts[:layout_opts][:views]
          opts[:layout_opts][:views] = app.expand_path(opts[:layout_opts][:views]).freeze
        end

        if layout = opts.fetch(:layout, true)
          opts[:layout] = true

          case layout
          when Hash
            opts[:layout_opts].merge!(layout)
          when true
            opts[:layout_opts][:template] ||= 'layout'
          else
            opts[:layout_opts][:template] = layout
          end

          opts[:optimize_layout] = (opts[:layout_opts][:template] if opts[:layout_opts].keys.sort == [:_is_layout, :template])
        end
        opts[:layout_opts].freeze

        template_opts = opts[:template_opts] = (opts[:template_opts] || {}).dup
        template_opts[:outvar] ||= '@_out_buf'
        unless template_opts.has_key?(:default_encoding)
          template_opts[:default_encoding] = Encoding.default_external
        end

        engine_opts = opts[:engine_opts] = (opts[:engine_opts] || {}).dup
        engine_opts.to_a.each do |k,v|
          engine_opts[k] = v.dup.freeze
        end

        if escape = opts[:escape]
          require 'tilt/erubi'

          case escape
          when String, Array
            Array(escape).each do |engine|
              engine_opts[engine] = (engine_opts[engine] || {}).merge(:escape => true).freeze
            end
          else
            template_opts[:escape] = true
          end
        end

        template_opts.freeze
        engine_opts.freeze
        opts.freeze
      end

      # Wrapper object for the Tilt template, that checks the modified
      # time of the template file, and rebuilds the template if the
      # template file has been modified.  This is an internal class and
      # the API is subject to change at any time.
      class TemplateMtimeWrapper
        def initialize(roda_class, opts, template_opts)
          @roda_class = roda_class
          @opts = opts
          @template_opts = template_opts
          reset_template

          @path = opts[:path]
          deps = opts[:dependencies]
          @dependencies = ([@path] + Array(deps)) if deps
          @mtime = template_last_modified
        end

        # If the template file exists and the modification time has
        # changed, rebuild the template file, then call render on it.
        def render(*args, &block)
          res = nil
          modified = false
          if_modified do
            res = @template.render(*args, &block)
            modified = true
          end
          modified ? res : @template.render(*args, &block)
        end

        # Return when the template was last modified.  If the template depends on any
        # other files, check the modification times of all dependencies and
        # return the maximum.
        def template_last_modified
          if deps = @dependencies
            deps.map{|f| File.mtime(f)}.max
          else
            File.mtime(@path)
          end
        end

        # If the template file has been updated, return true and update
        # the template object and the modification time. Other return false.
        def if_modified
          begin
            mtime = template_last_modified
          rescue
            # ignore errors
          else
            if mtime != @mtime
              reset_template
              yield
              @mtime = mtime
            end
          end
        end

        if COMPILED_METHOD_SUPPORT
          # Whether the underlying template uses fixed locals.
          def fixed_locals?
            Render.tilt_template_fixed_locals?(@template)
          end

          # Compile a method in the given module with the given name that will
          # call the compiled template method, updating the compiled template method
          def define_compiled_method(roda_class, method_name, locals_keys=EMPTY_ARRAY)
            mod = roda_class::RodaCompiledTemplates
            internal_method_name = :"_#{method_name}"
            begin
              mod.send(:define_method, internal_method_name, compiled_method(locals_keys, roda_class))
            rescue ::NotImplementedError
              return false
            end

            mod.send(:private, internal_method_name)
            mod.send(:define_method, method_name, &compiled_method_lambda(roda_class, internal_method_name, locals_keys))
            mod.send(:private, method_name)

            method_name
          end

          # Returns an appropriate value for the template method cache.
          def define_compiled_method_cache_value(roda_class, method_name, locals_keys=EMPTY_ARRAY)
            if compiled_method = define_compiled_method(roda_class, method_name, locals_keys)
              [compiled_method, false].freeze
            else
              compiled_method
            end
          end

          private

          # Return the compiled method for the current template object.
          def compiled_method(locals_keys=EMPTY_ARRAY, roda_class=nil)
            Render.tilt_template_compiled_method(@template, locals_keys, roda_class)
          end

          # Return the lambda used to define the compiled template method.  This
          # is separated into its own method so the lambda does not capture any
          # unnecessary local variables
          def compiled_method_lambda(roda_class, method_name, locals_keys=EMPTY_ARRAY)
            mod = roda_class::RodaCompiledTemplates
            template = self
            lambda do |locals, &block|
              template.if_modified do
                mod.send(:define_method, method_name, Render.tilt_template_compiled_method(template, locals_keys, roda_class))
                mod.send(:private, method_name)
              end

              _call_optimized_template_method([method_name, Render.tilt_template_fixed_locals?(template)], locals, &block)
            end
          end
        end

        private

        # Reset the template, done every time the template or one of its
        # dependencies is modified.
        def reset_template
          @template = @roda_class.create_template(@opts, @template_opts)
        end
      end

      module ClassMethods
        if COMPILED_METHOD_SUPPORT
          # If using compiled methods and there is an optimized layout, speed up
          # access to the layout method to improve the performance of view.
          def freeze
            begin
              _freeze_layout_method
            rescue
              # This is only for optimization, if any errors occur, they can be ignored.
              # One possibility for error is the app doesn't use a layout, but doesn't
              # specifically set the :layout=>false plugin option.
              nil
            end

            # Optimize _call_optimized_template_method if you know all templates
            # are going to be using fixed locals.
            if render_opts[:assume_fixed_locals] && !render_opts[:check_template_mtime]
              include AssumeFixedLocalsInstanceMethods
            end

            super
          end
        end

        # Return an Tilt::Template object based on the given opts and template_opts.
        def create_template(opts, template_opts)
          opts[:template_class].new(opts[:path], 1, template_opts, &opts[:template_block])
        end

        # A proc that returns content, used for inline templates, so that the template
        # doesn't hold a reference to the instance of the class
        def inline_template_block(content)
          Proc.new{content}
        end

        # Copy the rendering options into the subclass, duping
        # them as necessary to prevent changes in the subclass
        # affecting the parent class.
        def inherited(subclass)
          super
          opts = subclass.opts[:render] = subclass.opts[:render].dup
          if COMPILED_METHOD_SUPPORT
            opts[:template_method_cache] = (opts[:cache_class] || RodaCache).new
          end
          opts[:cache] = opts[:cache].dup
          opts.freeze
        end

        # Return the render options for this class.
        def render_opts
          opts[:render]
        end

        private

        # Precompile the layout method, to reduce method calls to look it up at runtime.
        def _freeze_layout_method
          if render_opts[:layout]
            instance = allocate
            # This needs to be called even if COMPILED_METHOD_SUPPORT is not set,
            # in order for the precompile_templates plugin to work correctly.
            instance.send(:retrieve_template, instance.send(:view_layout_opts, OPTS))

            if COMPILED_METHOD_SUPPORT && (layout_template = render_opts[:optimize_layout]) && !opts[:render][:optimized_layout_method_created]
                instance.send(:retrieve_template, :template=>layout_template, :cache_key=>nil, :template_method_cache_key => :_roda_layout)
                layout_method = opts[:render][:template_method_cache][:_roda_layout]
                define_method(:_layout_method){layout_method}
                private :_layout_method
                alias_method(:_layout_method, :_layout_method)
                opts[:render] = opts[:render].merge(:optimized_layout_method_created=>true)
            end
          end
        end
      end

      module InstanceMethods
        # Render the given template. See Render for details.
        def render(template, opts = (no_opts = true; optimized_template = _cached_template_method(template); OPTS), &block)
          if optimized_template
            _call_optimized_template_method(optimized_template, OPTS, &block)
          elsif !no_opts && opts.length == 1 && (locals = opts[:locals]) && (optimized_template = _optimized_render_method_for_locals(template, locals))
            _call_optimized_template_method(optimized_template, locals, &block)
          else
            opts = render_template_opts(template, opts)
            retrieve_template(opts).render((opts[:scope]||self), (opts[:locals]||OPTS), &block)
          end
        end

        # Return the render options for the instance's class.
        def render_opts
          self.class.render_opts
        end

        # Render the given template.  If there is a default layout
        # for the class, take the result of the template rendering
        # and render it inside the layout.  Blocks passed to view
        # are passed to render when rendering the template.
        # See Render for details.
        def view(template, opts = (content = _optimized_view_content(template) unless defined?(yield); OPTS), &block)
          if content
            # First, check if the optimized layout method has already been created,
            # and use it if so.  This way avoids the extra conditional and local variable
            # assignments in the next section.
            if layout_method = _layout_method
              return _call_optimized_template_method(layout_method, OPTS){content}
            end

            # If we have an optimized template method but no optimized layout method, create the
            # optimized layout method if possible and use it.  If you can't create the optimized
            # layout method, fall through to the slower approach.
            if layout_template = self.class.opts[:render][:optimize_layout]
              retrieve_template(:template=>layout_template, :cache_key=>nil, :template_method_cache_key => :_roda_layout)
              if layout_method = _layout_method
                return _call_optimized_template_method(layout_method, OPTS){content}
              end
            end
          else
            opts = parse_template_opts(template, opts)
            content = opts[:content] || render_template(opts, &block)
          end

          if layout_opts  = view_layout_opts(opts)
            content = render_template(layout_opts){content}
          end

          content
        end

        private

        if COMPILED_METHOD_SUPPORT
          # If there is an instance method for the template, return the instance
          # method symbol.  This optimization is only used for render/view calls
          # with a single string or symbol argument.
          def _cached_template_method(template)
            case template
            when String, Symbol
              if (method_cache = render_opts[:template_method_cache])
                _cached_template_method_lookup(method_cache, template)
              end
            end
          end

          # The key to use in the template method cache for the given template.
          def _cached_template_method_key(template)
            template
          end

          # Return the instance method symbol for the template in the method cache.
          def _cached_template_method_lookup(method_cache, template)
            method_cache[template]
          end

          # Return a symbol containing the optimized layout method
          def _layout_method
            self.class.opts[:render][:template_method_cache][:_roda_layout]
          end

          # Use an optimized render path for templates with a hash of locals.  Returns the result
          # of the template render if the optimized path is used, or nil if the optimized
          # path is not used and the long method needs to be used.
          def _optimized_render_method_for_locals(template, locals)
            render_opts = self.render_opts
            return unless method_cache = render_opts[:template_method_cache]

            case template
            when String, Symbol
              if fixed_locals = render_opts[:assume_fixed_locals]
                key = template
                if optimized_template = _cached_template_method_lookup(method_cache, key)
                  return optimized_template
                end
              else
                key = [:_render_locals, template]
                if optimized_template = _cached_template_method_lookup(method_cache, key)
                  # Fixed locals case
                  return optimized_template
                end

                locals_keys = locals.keys.sort
                key << locals_keys
                if optimized_template = _cached_template_method_lookup(method_cache, key)
                  # Regular locals case
                  return optimized_template
                end
              end
            else
              return
            end

            if method_cache_key = _cached_template_method_key(key)
              template_obj = retrieve_template(render_template_opts(template, NO_CACHE))
              unless fixed_locals
                key.pop if fixed_locals = Render.tilt_template_fixed_locals?(template_obj)
                key.freeze
              end
              method_name = :"_roda_template_locals_#{self.class.object_id}_#{method_cache_key}"

              method_cache[method_cache_key] = case template_obj
              when Render::TemplateMtimeWrapper
                template_obj.define_compiled_method_cache_value(self.class, method_name, locals_keys)
              else
                begin
                  unbound_method = Render.tilt_template_compiled_method(template_obj, locals_keys, self.class)
                rescue ::NotImplementedError
                  false
                else
                  self.class::RodaCompiledTemplates.send(:define_method, method_name, unbound_method)
                  self.class::RodaCompiledTemplates.send(:private, method_name)
                  [method_name, fixed_locals].freeze
                end
              end
            end
          end

          # Get the content for #view, or return nil to use the unoptimized approach. Only called if
          # a single argument is passed to view.
          def _optimized_view_content(template)
            if optimized_template = _cached_template_method(template)
              _call_optimized_template_method(optimized_template, OPTS)
            elsif template.is_a?(Hash) && template.length == 1
              template[:content]
            end
          end

          if RUBY_VERSION >= '3'
            class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
              def _call_optimized_template_method((meth, fixed_locals), locals, &block)
                if fixed_locals
                  send(meth, **locals, &block)
                else
                  send(meth, locals, &block)
                end
              end
            RUBY
          # simplecov:disable
          elsif RUBY_VERSION >= '2'
            class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
              def _call_optimized_template_method((meth, fixed_locals), locals, &block)
                if fixed_locals
                  if locals.empty?
                    send(meth, &block)
                  else
                    send(meth, **locals, &block)
                  end
                else
                  send(meth, locals, &block)
                end
              end
            RUBY
          else
            # Call the optimized template method.  This is designed to be used with the
            # method cache, which caches the method name and whether the method uses
            # fixed locals.  Methods with fixed locals need to be called with a keyword
            # splat.
            def _call_optimized_template_method((meth, fixed_locals), locals, &block)
              send(meth, locals, &block)
            end
          end
          # simplecov:enable
        else
          def _cached_template_method(_)
            nil
          end

          def _cached_template_method_key(_)
            nil
          end

          def _optimized_render_method_for_locals(_, _)
            nil
          end

          def _optimized_view_content(template)
            nil
          end
        end

        # Convert template options to single hash when rendering templates using render.
        def render_template_opts(template, opts)
          parse_template_opts(template, opts)
        end

        # Private alias for render.  Should be used by other plugins when they want to render a template
        # without a layout, as plugins can override render to use a layout.
        alias render_template render

        # If caching templates, attempt to retrieve the template from the cache.  Otherwise, just yield
        # to get the template.
        def cached_template(opts, &block)
          if key = opts[:cache_key]
            cache = render_opts[:cache]
            unless template = cache[key]
              template = cache[key] = yield
            end
            template
          else
            yield
          end
        end

        # Given the template name and options, set the template class, template path/content,
        # template block, and locals to use for the render in the passed options.
        def find_template(opts)
          render_opts = self.class.opts[:render]
          engine_override = opts[:engine]
          engine = opts[:engine] ||= render_opts[:engine]
          if content = opts[:inline]
            path = opts[:path] = content
            template_class = opts[:template_class] ||= ::Tilt[engine]
            opts[:template_block] = self.class.inline_template_block(content)
          else
            opts[:views] ||= render_opts[:views]
            path = opts[:path] ||= template_path(opts)
            template_class = opts[:template_class]
            opts[:template_class] ||= ::Tilt
          end

          if (cache = opts[:cache]).nil?
            cache = content || !opts[:template_block]
          end

          if cache
            unless opts.has_key?(:cache_key)
              template_block = opts[:template_block] unless content
              template_opts = opts[:template_opts]

              opts[:cache_key] = if template_class || engine_override || template_opts || template_block
                [path, template_class, engine_override, template_opts, template_block]
              else
                path
              end
            end
          else
            opts.delete(:cache_key)
          end

          opts
        end

        # Return a single hash combining the template and opts arguments.
        def parse_template_opts(template, opts)
          opts = Hash[opts]
          if template.is_a?(Hash)
            opts.merge!(template)
          else
            if opts.empty? && (key = _cached_template_method_key(template))
              opts[:template_method_cache_key] = key
            end
            opts[:template] = template
            opts
          end
        end

        # The default render options to use.  These set defaults that can be overridden by
        # providing a :layout_opts option to the view/render method.
        def render_layout_opts
          Hash[render_opts[:layout_opts]]
        end

        # Retrieve the Tilt::Template object for the given template and opts.
        def retrieve_template(opts)
          cache = opts[:cache]
          if !opts[:cache_key] || cache == false
            found_template_opts = opts = find_template(opts)
          end
          cached_template(opts) do
            opts = found_template_opts || find_template(opts)
            render_opts = self.class.opts[:render]
            template_opts = render_opts[:template_opts]
            if engine_opts = render_opts[:engine_opts][opts[:engine]]
              template_opts = template_opts.merge(engine_opts)
            end
            if current_template_opts = opts[:template_opts]
              template_opts = template_opts.merge(current_template_opts)
            end

            define_compiled_method = COMPILED_METHOD_SUPPORT &&
               (method_cache_key = opts[:template_method_cache_key]) &&
               (method_cache = render_opts[:template_method_cache]) &&
               (method_cache[method_cache_key] != false) &&
               !opts[:inline]

            if render_opts[:check_template_mtime] && !opts[:template_block] && !cache
              template = TemplateMtimeWrapper.new(self.class, opts, template_opts)

              if define_compiled_method
                method_name = :"_roda_template_#{self.class.object_id}_#{method_cache_key}"
                method_cache[method_cache_key] = template.define_compiled_method_cache_value(self.class, method_name)
              end
            else
              template = self.class.create_template(opts, template_opts)

              if define_compiled_method && cache != false
                begin
                  unbound_method = Render.tilt_template_compiled_method(template, EMPTY_ARRAY, self.class)
                rescue ::NotImplementedError
                  method_cache[method_cache_key] = false
                else
                  method_name = :"_roda_template_#{self.class.object_id}_#{method_cache_key}"
                  self.class::RodaCompiledTemplates.send(:define_method, method_name, unbound_method)
                  self.class::RodaCompiledTemplates.send(:private, method_name)
                  method_cache[method_cache_key] = [method_name, Render.tilt_template_fixed_locals?(template)].freeze
                end
              end
            end

            template
          end
        end

        # The name to use for the template.  By default, just converts the :template option to a string.
        def template_name(opts)
          opts[:template].to_s
        end

        # The template path for the given options.
        def template_path(opts)
          path = "#{opts[:views]}/#{template_name(opts)}.#{opts[:engine]}"
          if opts.fetch(:check_paths){render_opts[:check_paths]}
            full_path = self.class.expand_path(path)
            unless render_opts[:allowed_paths].any?{|f| full_path.start_with?(f)}
              raise RodaError, "attempt to render path not in allowed_paths: #{full_path} (allowed: #{render_opts[:allowed_paths].join(', ')})"
            end
          end
          path
        end

        # If a layout should be used, return a hash of options for
        # rendering the layout template.  If a layout should not be
        # used, return nil.
        def view_layout_opts(opts)
          if layout = opts.fetch(:layout, render_opts[:layout])
            layout_opts = render_layout_opts

            method_layout_opts = opts[:layout_opts]
            layout_opts.merge!(method_layout_opts) if method_layout_opts

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

      module AssumeFixedLocalsInstanceMethods
        # simplecov:disable
        if RUBY_VERSION >= '3.0'
        # simplecov:enable
          class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
            def _call_optimized_template_method((meth,_), locals, &block)
              send(meth, **locals, &block)
            end
          RUBY
        end
      end
    end

    register_plugin(:render, Render)
  end
end
