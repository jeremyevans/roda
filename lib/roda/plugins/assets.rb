require "tilt"
require 'open-uri'

class Roda
  module RodaPlugins
    module Assets
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
        def assets_unique_id type
          if unique_id = instance_variable_get("@#{type}")
            unique_id
          else
            path    = "#{assets_opts[:compiled_path]}/#{assets_opts[:"#{type}_folder"]}"
            file    = "#{path}/#{assets_opts[:compiled_name]}.#{type}"
            content = File.exist?(file) ? File.read(file) : ''

            instance_variable_set("@#{type}", Digest::SHA1.hexdigest(content))
          end
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
          if !assets_opts[:concat]
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
          else
            name = assets_opts[:compiled] ? assets_opts[:compiled_name] : assets_opts[:concat_name]
            name = "#{name}/#{folder.join('-')}"
            # Generate unique url so middleware knows to check for # compile/concat
            attrs.unshift("#{attr}=\"/#{path}/#{name}/#{assets_unique_id(type)}.#{type}\"")
            # Return tag string
            send("#{type}_assets_tag", attrs.join(' '))
          end
        end

        def render_asset(file, type)
          file.gsub!(/(\$2E|%242E)/, '.')

          if !assets_opts[:compiled] && !assets_opts[:concat]
            read_asset_file file, type
          elsif assets_opts[:compiled]
            path = assets_opts[:compiled_path] \
                   + "/#{assets_opts[:"#{type}_folder"]}/" \
                   + assets_opts[:compiled_name] + ".#{type}"

            File.read path
          elsif assets_opts[:concat]
            # "concat.roda.assets/css/123"
            html   = ''
            folder = file.split('/')[1].split('-', 1)
            files  = folder.length == 1 \
                    ? assets_opts[:"#{folder[0]}"] \
                    : assets_opts[:"#{folder[0]}"][:"#{folder[1]}"]

            files.each do |f|
              html += read_asset_file f, type
            end

            html
          end
        end

        def read_asset_file file, type
          folder = assets_opts[:"#{type}_folder"]

          # If there is no file it must be a remote file request.
          # Lets set the file to the url
          if file == ''
            route = assets_opts[:route]
            file  = env['SCRIPT_NAME'].gsub(/^\/#{route}\/#{folder}\//, '')
          end

          if !file[/^\.\//] && !file[/^http/]
            path = assets_opts[:path] + '/' + folder + "/#{file}"
          else
            path = file
          end

          engine = assets_opts[:"#{type}_engine"]

          # render via tilt
          if File.exists? "#{path}.#{engine}"
            render path: "#{path}.#{engine}"
          # read file directly
          elsif File.exists? "#{path}.#{type}"
            File.read "#{path}.#{type}"
          # grab remote file content
          elsif file[/^http/]
            open(file).read
          # as a last attempt lets see if the file can be rendered by tilt
          # otherwise load the file directly
          elsif File.exists? path
            begin
              render path: path
            rescue
              File.read path
            end
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
        def css_assets_tag attrs
          "<link rel=\"stylesheet\" #{attrs} />"
        end

        # JS tag template
        # <script src="scriptfile.js"></script>
        def js_assets_tag attrs
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
