# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The path plugin adds support for named paths.  Using the +path+ class method, you can
    # easily create <tt>*_path</tt> instance methods for each named path.  Those instance
    # methods can then be called if you need to get the path for a form action, link,
    # redirect, or anything else.
    #
    # Additionally, you can call the +path+ class method with a class and a block, and it will register
    # the class.  You can then call the +path+ instance method with an instance of that class, and it will
    # execute the block in the context of the route block scope with the arguments provided to path. You
    # can call the +url+ instance method with the same arguments as the +path+ method to get the full URL.
    #
    # Example:
    #
    #   plugin :path
    #   path :foo, '/foo'
    #   path :bar do |bar|
    #     "/bar/#{bar.id}"
    #   end
    #   path Baz do |baz, *paths|
    #     "/baz/#{baz.id}/#{paths.join('/')}"
    #   end
    #   path Quux do |quux, path|
    #     "/quux/#{quux.id}/#{path}"
    #   end
    #
    #   route do |r|
    #     r.post 'foo' do
    #       r.redirect foo_path # /foo
    #     end
    #
    #     r.post 'bar' do
    #       bar_params = r.params['bar']
    #       if bar_params.is_a?(Hash)
    #         bar = Bar.create(bar_params)
    #         r.redirect bar_path(bar) # /bar/1
    #       end
    #     end
    #
    #     r.post 'baz' do
    #       baz = Baz[1]
    #       r.redirect path(baz, 'c', 'd') # /baz/1/c/d
    #     end
    #
    #     r.post 'quux' do
    #       quux = Quux[1]
    #       r.redirect url(quux, '/bar') # http://example.com/quux/1/bar
    #     end
    #   end
    #
    # The path class method accepts the following options when not called with a class:
    #
    # :add_script_name :: Prefix the path generated with SCRIPT_NAME. This defaults to the app's
    #                     :add_script_name option.
    # :name :: Provide a different name for the method, instead of using <tt>*_path</tt>.
    # :relative :: Generate paths relative to the current request instead of absolute paths by prepending
    #              an appropriate prefix.  This implies :add_script_name.
    # :url :: Create a url method in addition to the path method, which will prefix the string generated
    #         with the appropriate scheme, host, and port.  If true, creates a <tt>*_url</tt>
    #         method.  If a Symbol or String, uses the value as the url method name.
    # :url_only :: Do not create a path method, just a url method.
    #
    # Note that if :add_script_name, :relative, :url, or :url_only is used, the path method will also create a
    # <tt>_*_path</tt> private method.
    module Path
      DEFAULT_PORTS = {'http' => 80, 'https' => 443}.freeze

      # Initialize the path classes when loading the plugin. Options:
      # :by_name :: Register classes by name, which is friendlier when reloading code (defaults to
      #             true in development mode)
      def self.configure(app, opts=OPTS)
        app.instance_eval do
          self.opts[:path_class_by_name] = opts.fetch(:by_name, ENV['RACK_ENV'] == 'development')
          self.opts[:path_classes] ||= {}
          self.opts[:path_class_methods] ||= {}
          unless path_block(String)
            path(String){|str| str}
          end
        end
      end

      module ClassMethods
        # Hash of recognizes classes for path instance method.  Keys are classes, values are procs.
        def path_classes
          opts[:path_classes]
        end

        # Freeze the path classes when freezing the app.
        def freeze
          path_classes.freeze
          opts[:path_classes_methods].freeze
          super
        end

        # Create a new instance method for the named path.  See plugin module documentation for options.
        def path(name, path=nil, opts=OPTS, &block)
          if name.is_a?(Class)
            raise RodaError, "can't provide path or options when calling path with a class" unless path.nil? && opts.empty?
            raise RodaError, "must provide a block when calling path with a class" unless block
            if self.opts[:path_class_by_name]
              name = name.name
            end
            path_classes[name] = block
            self.opts[:path_class_methods][name] = define_roda_method("path_#{name}", :any, &block)
            return
          end

          if path.is_a?(Hash)
            raise RodaError,  "cannot provide two option hashses to Roda.path" unless opts.empty?
            opts = path
            path = nil
          end

          raise RodaError,  "cannot provide both path and block to Roda.path" if path && block
          raise RodaError,  "must provide either path or block to Roda.path" unless path || block

          if path
            path = path.dup.freeze
            block = lambda{path}
          end

          meth = opts[:name] || "#{name}_path"
          url = opts[:url]
          url_only = opts[:url_only]
          relative = opts[:relative]
          add_script_name = opts.fetch(:add_script_name, self.opts[:add_script_name])

          if relative
            if (url || url_only)
              raise RodaError,  "cannot provide :url or :url_only option if using :relative option"
            end
            add_script_name = true
            plugin :relative_path
          end

          if add_script_name || url || url_only || relative
            _meth = "_#{meth}"
            define_method(_meth, &block)
            private _meth
          end

          unless url_only
            if relative
              define_method(meth) do |*a, &blk|
                # Allow calling private _method to get path
                relative_path(request.script_name.to_s + send(_meth, *a, &blk))
              end
              ruby2_keywords(meth) if respond_to?(:ruby2_keywords, true)
            elsif add_script_name
              define_method(meth) do |*a, &blk|
                # Allow calling private _method to get path
                request.script_name.to_s + send(_meth, *a, &blk)
              end
              ruby2_keywords(meth) if respond_to?(:ruby2_keywords, true)
            else
              define_method(meth, &block)
            end
          end

          if url || url_only
            url_meth = if url.is_a?(String) || url.is_a?(Symbol)
              url
            else
              "#{name}_url"
            end

            url_block = lambda do |*a, &blk|
              # Allow calling private _method to get path
              "#{_base_url}#{request.script_name if add_script_name}#{send(_meth, *a, &blk)}"
            end

            define_method(url_meth, &url_block)
            ruby2_keywords(url_meth) if respond_to?(:ruby2_keywords, true)
          end

          nil
        end
        
        # Return the block related to the given class, or nil if there is no block.
        def path_block(klass)
          # RODA4: Remove
          if opts[:path_class_by_name]
            klass = klass.name
          end
          path_classes[klass]
        end
      end

      module InstanceMethods
        # Return a path based on the class of the object.  The object passed must have
        # had its class previously registered with the application.  If the app's
        # :add_script_name option is true, this prepends the SCRIPT_NAME to the path.
        def path(obj, *args, &block)
          app = self.class
          opts = app.opts
          klass =  opts[:path_class_by_name] ? obj.class.name : obj.class
          unless meth = opts[:path_class_methods][klass]
            raise RodaError, "unrecognized object given to Roda#path: #{obj.inspect}"
          end

          path = send(meth, obj, *args, &block)
          path = request.script_name.to_s + path if opts[:add_script_name]
          path
        end

        # Similar to #path, but returns a complete URL.
        def url(*args, &block)
          "#{_base_url}#{path(*args, &block)}"
        end

        private

        # The string to prepend to the path to make the path a URL.
        def _base_url
          r = @_request
          scheme = r.scheme
          port = r.port
          "#{scheme}://#{r.host}#{":#{port}" unless DEFAULT_PORTS[scheme] == port}"
        end
      end
    end

    register_plugin(:path, Path)
  end
end
