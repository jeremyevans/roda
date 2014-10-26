class Roda
  module RodaPlugins
    module Assets
      # The assets plugin adds support for rendering your front end files using
      # the tilt library.  You have one instance method +assets+ and a class
      # method +compile_assets+.
      #
      #   plugin(:assets, {
      #     css: ['some_file'],
      #     js:  ['some_file']
      #   })
      #
      #   route do |r|
      #     r.assets
      #   end
      #
      # In your views you'd then use the code below to render tags for each file
      #   assets(:css)
      #   assets(:js)
      #
      # You can add attributes to the tags by simply doing:
      #   assets(:css, media: 'print')
      #
      # Assets also supports groups incase you have different css/js files for
      # your front end and back end.  To do this you'd simply do:
      #
      #   plugin(:assets {
      #     css: {
      #       frontend: ['some_frontend_file'],
      #       backend:  ['some_backend_file']
      #     }
      #   })
      #
      # Then in your view code just do:
      #   assets [:css, :frontend]
      #
      # You can provide options to the plugin method, or later by modifying
      # +assets_opts+.
      #
      # :js_folder :: Folder name containing your javascript.
      # :css_folder :: Folder name containing your stylesheets.
      # :path :: Path to your assets directory.
      # :compiled_path :: Path to save your compiled files to.
      # :compiled_name :: Compiled file name.
      # :prefix :: prefix for assets path, including trailing slash if not empty (default: 'assets/')
      # :css_engine :: default engine to use for css.
      # :js_engine :: default engine to use for js.
      # :concat :: Boolean to turn on and off concating files.
      # :compiled :: Boolean to turn on and off using compiled files.
      # :headers :: Add additional headers to your rendered files.

      def self.load_dependencies(app, _opts)
        app.plugin :render
      end

      def self.configure(app, opts = {}, &_block)
        if app.opts[:assets]
          app.opts[:assets].merge!(opts)
        else
          app.opts[:assets] = opts.dup
        end

        opts                   = app.opts[:assets]
        opts[:css]           ||= []
        opts[:js]            ||= []
        opts[:js_folder]     ||= 'js'
        opts[:css_folder]    ||= 'css'
        opts[:path]          ||= File.expand_path('assets', Dir.pwd)
        opts[:compiled_path] ||= opts[:path]
        opts[:compiled_name] ||= 'compiled.roda.assets'
        opts[:prefix]        ||= 'assets/'
        opts[:css_engine]    ||= 'scss'
        opts[:js_engine]     ||= 'coffee'
        opts[:concat]        ||= false
        opts[:compiled]      ||= false
        opts[:headers]       ||= {}

        opts.fetch(:cache, true) && opts[:cache] = app.thread_safe_cache
      end

      # need to flattern js/css opts

      module ClassMethods
        # Copy the assets options into the subclass, duping
        # them as necessary to prevent changes in the subclass
        # affecting the parent class.
        def inherited(subclass)
          super
          opts         = subclass.opts[:assets] = assets_opts.dup
          opts[:css]   = opts[:css].dup
          opts[:js]    = opts[:js].dup
          opts[:cache] = thread_safe_cache if opts[:cache]
        end

        # Return the assets options for this class.
        def assets_opts
          opts[:assets]
        end

        # Generates a unique id, this is used to keep concat/compiled files
        # from caching in the browser when they are generated
        def assets_unique_id(type)
          if (unique_id = instance_variable_get("@#{type}"))
            unique_id
          else
            path    = "#{assets_opts[:compiled_path]}\
                      /#{assets_opts[:"#{type}_folder"]}"
            file    = "#{path}/#{assets_opts[:compiled_name]}.#{type}"
            content = File.exist?(file) ? File.read(file) : ''

            instance_variable_set("@#{type}", Digest::SHA1.hexdigest(content))
          end
        end

        def compile_assets(concat_only = false)
          # if true don't YUI compress
          assets_opts[:concat_only] = concat_only

          %w(css js).each do |type|
            files = assets_opts[type.to_sym]

            if files.is_a? Array
              compile_process_files(files, type, type)
            else
              files.each do |folder, f|
                compile_process_files(f, type, folder)
              end
            end
          end
        end

        private

        def compile_process_files(files, type, folder)
          # start app instance
          app = new

          # content to render to file
          content = ''

          files.each do |file|
            (type != folder && !file[/\A\.\//]) && file = "#{folder}/#{file}"
            content << app.read_asset_file(file, type)
          end

          path = assets_opts[:compiled_path] \
                 + "/#{assets_opts[:"#{type}_folder"]}/" \
                 + assets_opts[:compiled_name] \
                 + (type != folder ? ".#{folder}" : '') \
                 + ".#{type}"

          unless assets_opts[:concat_only]
            begin
              require 'yuicompressor'
              content = YUICompressor.send("compress_#{type}", content, :munge => true)
            rescue LoadError
              # yuicompressor not available, just use concatenated, uncompressed output
            end
          end

          File.open(path, 'wb'){|f| f.write(content)}
        end
      end

      module InstanceMethods
        # This will ouput the files with the appropriate tags
        def assets(folder, options = {})
          attrs   = options.map{ |k, v| "#{k}=\"#{v}\"" }
          tags    = []
          folder  = [folder] unless folder.is_a? Array
          type    = folder.first
          attr    = type.to_s == 'js' ? 'src' : 'href'
          path    = "#{assets_opts[:prefix]}#{assets_opts[:"#{type}_folder"]}"

          # Create a tag for each individual file
          if assets_opts[:compiled] || assets_opts[:concat]
            name = "#{assets_opts[:compiled_name]}/#{folder.join('-')}"
            # Generate unique url so middleware knows
            # to check for # compile/concat
            attrs.unshift(
              "#{attr}=\"/#{path}/#{name}/#{assets_unique_id(type)}.#{type}\""
            )
            # Return tag string
            send("#{type}_assets_tag", attrs.join(' '))
          else
            files = (folder.length == 1 ? assets_opts[:"#{folder[0]}"] : \
                    assets_opts[:"#{folder[0]}"][:"#{folder[1]}"])

            files.each do |file|
              # This allows you to do things like:
              # assets_opts[:css] = ['app', './bower/jquery/jquery-min.js']
              file.gsub!(/\./, '$2E')
              # Add tags to the tags array
              tags << send(
                "#{type}_assets_tag",
                attrs.dup.unshift("#{attr}=\"/#{path}/#{file}.#{type}\"")
                         .join(' ')
              )
            end
            # Return tags as string
            tags.join "\n"
          end
        end

        def render_asset(file, type)
          # convert back url safe to period
          file.gsub!(/(\$2E|%242E)/, '.')

          if !assets_opts[:compiled] && !assets_opts[:concat]
            read_asset_file file, type
          elsif assets_opts[:compiled]
            folder = file.split('/')[1].split('-', 2)
            path   = "#{assets_opts[:compiled_path]}/" << \
                     "#{assets_opts[:"#{type}_folder"]}/" << \
                     "#{assets_opts[:compiled_name]}" << \
                     "#{(folder.length > 1 ? ".#{folder[1]}" : '')}.#{type}"

            File.read(path)
          else
            content = ''
            folder  = file.split('/')[1].split('-', 2)
            files = (folder.length == 1 ? assets_opts[:"#{folder[0]}"] : \
                    assets_opts[:"#{folder[0]}"][:"#{folder[1]}"])

            files.each { |f| content << read_asset_file(f, type) }

            content
          end
        end

        def read_asset_file(file, type)
          # set the current engine
          engine = assets_opts[:"#{type}_engine"]

          # set the current folder
          folder = assets_opts[:"#{type}_folder"]

          # If it's not a parent directory append the full path
          !file[/\A\.\//] && file = "#{assets_opts[:path]}/#{folder}/#{file}"

          if File.exist?("#{file}.#{engine}")
            # render via tilt
            render path: "#{file}.#{engine}"
          elsif File.exist?("#{file}.#{type}")
            # read file directly
            File.read("#{file}.#{type}")
          elsif file =~ /\.#{type}\z/
            File.read(file)
          else
            render(path: file)
          end
        end

        # Shortcut for class opts
        def assets_opts
          self.class.assets_opts
        end

        # Shortcut for class assets unique id
        def assets_unique_id(*args)
          self.class.assets_unique_id(*args)
        end

        private

        # CSS tag template
        # <link rel="stylesheet" href="theme.css">
        def css_assets_tag(attrs)
          "<link rel=\"stylesheet\" #{attrs} />"
        end

        # JS tag template
        # <script src="scriptfile.js"></script>
        def js_assets_tag(attrs)
          "<script type=\"text/javascript\" #{attrs}></script>"
        end
      end

      module RequestClassMethods
        # Shortcut for roda class asset opts
        def assets_opts
          roda_class.assets_opts
        end

        # The regexp for the assets route
        def assets_route_regexp
          # FIXME: Should be changed to only match known assets
          @assets_route_regexp ||= %r{#{assets_opts[:prefix]}(?:#{assets_opts[:css_folder]}|#{assets_opts[:js_folder]})/(.+)\.(css|js)\z}
        end
      end

      module RequestMethods
        # Handles calls to the assets route
        def assets
          on self.class.assets_route_regexp do |file, type|
            content_type = type == 'css' ? 'text/css' : 'application/javascript'

            response.headers.merge!({
              'Content-Type' => "#{content_type}; charset=UTF-8"
            }.merge(scope.assets_opts[:headers]))

            scope.render_asset file, type
          end
        end
      end
    end

    register_plugin(:assets, Assets)
  end
end
