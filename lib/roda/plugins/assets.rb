require "tilt"
require 'net/http'
require 'uri'

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
      # In your views you'd then use the code below to render tags for each file:
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
      # :concat_name :: Concated file name.

      def self.load_dependencies(app, opts={})
        app.plugin :render
      end

      def self.configure(app, opts={}, &block)
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
        opts[:path]          ||= File.expand_path("assets", Dir.pwd)
        opts[:compiled_path] ||= opts[:path]
        opts[:compiled_name] ||= 'compiled.roda.assets'
        opts[:concat_name]   ||= 'concat.roda.assets'
        opts[:route]         ||= 'assets'
        opts[:css_engine]    ||= 'scss'
        opts[:js_engine]     ||= 'coffee'
        opts[:concat]        ||= false
        opts[:compiled]      ||= false
        opts[:headers]       ||= {}

        if opts.fetch(:cache, true)
          opts[:cache] = app.thread_safe_cache
        end
      end

      module ClassMethods
        # Copy the assets options into the subclass, duping
        # them as necessary to prevent changes in the subclass
        # affecting the parent class.
        def inherited(subclass)
          super
          opts         = subclass.opts[:assets] = assets_opts.dup
          opts[:cache] = thread_safe_cache if opts[:cache]
        end

        # Return the assets options for this class.
        def assets_opts
          opts[:assets]
        end

        # Generates a unique id, this is used to keep concat/compiled files
        # from caching in the browser when they are generated
        def assets_unique_id(type)
          if unique_id = instance_variable_get("@#{type}")
            unique_id
          else
            path    = "#{assets_opts[:compiled_path]}/#{assets_opts[:"#{type}_folder"]}"
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
              compile_process_files files, type, type
            else
              files.each do |folder, f|
                compile_process_files f, type, folder
              end
            end
          end
        end

        private

        def compile_process_files(files, type, folder)
          require 'yuicompressor'

          # start app instance
          app = new

          # content to render to file
          content = ''

          files.each do |file|
            if type != folder && !file[/^\.\//] && !file[/^http/]
              file = "#{folder}/#{file}"
            end

            content += app.read_asset_file file, type
          end

          path = assets_opts[:compiled_path] \
                 + "/#{assets_opts[:"#{type}_folder"]}/" \
                 + assets_opts[:compiled_name] \
                 + (type != folder ? ".#{folder}" : '') \
                 + ".#{type}"

          unless assets_opts[:concat_only]
            content = YUICompressor.send("compress_#{type}", content, munge: true)
          end

          File.write path, content
        end
      end

      module InstanceMethods
        # This will ouput the files with the appropriate tags
        def assets folder, options = {}
          attrs   = options.map{|k,v| "#{k}=\"#{v}\""}
          tags    = []
          folder  = [folder] unless folder.is_a? Array
          type    = folder.first
          attr    = type.to_s == 'js' ? 'src' : 'href'
          path    = "#{assets_opts[:route]}/#{assets_opts[:"#{type}_folder"]}"
          files   = folder.length == 1 \
                  ? assets_opts[:"#{folder[0]}"] \
                  : assets_opts[:"#{folder[0]}"][:"#{folder[1]}"]

          # Create a tag for each individual file
          if assets_opts[:compiled] || assets_opts[:concat]
            name = assets_opts[:compiled] ? assets_opts[:compiled_name] : assets_opts[:concat_name]
            name = "#{name}/#{folder.join('-')}"
            # Generate unique url so middleware knows to check for # compile/concat
            attrs.unshift("#{attr}=\"/#{path}/#{name}/#{assets_unique_id(type)}.#{type}\"")
            # Return tag string
            send("#{type}_assets_tag", attrs.join(' '))
          else
            files.each do |file|
              # This allows you to do things like:
              # assets_opts[:css] = ['app', './bower/jquery/jquery-min.js']
              file.gsub!(/\./, '$2E')
              # Add tags to the tags array
              tags << send(
                "#{type}_assets_tag",
                attrs.dup.unshift( "#{attr}=\"/#{path}/#{file}.#{type}\"").join(' ')
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
            path   = assets_opts[:compiled_path] \
                   + "/#{assets_opts[:"#{type}_folder"]}/" \
                   + assets_opts[:compiled_name] \
                   + (folder.length > 1 ? ".#{folder[1]}" : '') \
                   + ".#{type}"

            File.read path
          elsif assets_opts[:concat]
            # "concat.roda.assets/css/123"
            content   = ''
            folder = file.split('/')[1].split('-', 2)
            files  = folder.length == 1 \
                    ? assets_opts[:"#{folder[0]}"] \
                    : assets_opts[:"#{folder[0]}"][:"#{folder[1]}"]

            files.each { |f| content += read_asset_file f, type }

            content
          end
        end

        def read_asset_file(file, type)
          # set the current engine
          engine = assets_opts[:"#{type}_engine"]

          # set the current folder
          folder = assets_opts[:"#{type}_folder"]

          # If there is no file it must be a remote file request.
          # Lets set the file to the url
          if file == ''
            route = assets_opts[:route]
            file  = env['SCRIPT_NAME'].gsub(/^\/#{route}\/#{folder}\//, '')
          end

          # If it's not a url or parent direct append the full path
          if !file[/^\.\//] && !file[/^http/]
            file = assets_opts[:path] + '/' + folder + "/#{file}"
          end

          if File.exists? "#{file}.#{engine}"
            # render via tilt
            render path: "#{file}.#{engine}"
          elsif File.exists? "#{file}.#{type}"
            # read file directly
            File.read "#{file}.#{type}"
          elsif file[/^http/]
            # grab remote file content
            Net::HTTP.get(URI.parse(file))
          elsif File.exists?(file) && !file[/\.#{type}$/]
            # Render via tilt if the type isn't css or js
            render path: file
          else
            # if it is css/js read the file directly
            File.read file
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

        # The regex for the assets route
        def assets_route_regex
          Regexp.new(
            assets_opts[:route] + '/' +
            "(#{assets_opts[:"css_folder"]}|#{assets_opts[:"js_folder"]})" +
            '/(.*)(?:\.(css|js)|http.*)$'
          )
        end
      end

      module RequestMethods
        # Handles calls to the assets route
        def assets
          on self.class.assets_route_regex do |type, file|
            content_type = type == 'css' ? 'text/css' : 'application/javascript'

            response.headers.merge!({
              "Content-Type" => content_type + '; charset=UTF-8',
            }.merge(scope.assets_opts[:headers]))

            scope.render_asset file, type
          end
        end
      end
    end

    register_plugin(:assets, Assets)
  end
end
