class Roda
  module RodaPlugins
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
    # :concat_only :: whether to just concatenate instead of concatentating
    #                 and compressing files (default: false)
    # :compiled :: whether to turn on using compiled files (default: false)
    # :headers :: Add additional headers to both js and css rendered files.
    # :css_headers :: Add additional headers to your css rendered files.
    # :js_headers :: Add additional headers to your js rendered files.
    # :unique_ids :: A hash of types/folders to the unique id for the compiled asset file.
    module Assets

      def self.load_dependencies(app, _opts)
        app.plugin :render
      end

      def self.configure(app, opts = {})
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
        opts[:concat_only]   = false unless opts.has_key?(:concat_only)
        opts[:compiled]      = false unless opts.has_key?(:compiled)
        opts[:unique_ids]    ||= {} 

        opts[:css_headers]   ||= {} 
        opts[:js_headers]    ||= {} 
        if headers = opts[:headers]
          opts[:css_headers] ||= headers.merge(opts[:css_headers])
          opts[:js_headers]  ||= headers.merge(opts[:js_headers])
        end
        opts[:css_headers]['Content-Type'] ||= "text/css; charset=UTF-8"
        opts[:js_headers]['Content-Type']  ||= "application/javascript; charset=UTF-8"

        if opts.fetch(:cache, true)
          opts[:cache] = app.thread_safe_cache
        end
      end

      # need to flattern js/css opts

      module ClassMethods
        # Copy the assets options into the subclass, duping
        # them as necessary to prevent changes in the subclass
        # affecting the parent class.
        def inherited(subclass)
          super
          opts               = subclass.opts[:assets] = assets_opts.dup
          opts[:css]         = opts[:css].dup
          opts[:js]          = opts[:js].dup
          opts[:css_headers] = opts[:css_headers].dup
          opts[:js_headers]  = opts[:js_headers].dup
          opts[:cache] = thread_safe_cache if opts[:cache]
        end

        # Return the assets options for this class.
        def assets_opts
          opts[:assets]
        end

        def compile_assets
          unique_ids = {}

          %w(css js).each do |type|
            files = assets_opts[type.to_sym]

            if files.is_a? Array
              key, id = compile_process_files(files, type, type)
              unique_ids[key] = id
            else
              files.each do |folder, f|
                key, id = compile_process_files(f, type, folder)
                unique_ids[key] = id
              end
            end
          end

          unique_ids
        end

        private

        def compile_process_files(files, type, folder)
          # start app instance
          app = new

          # content to render to file
          content = ''

          files.each do |file|
            if type != folder && file !~ /\A\.\//
              file = "#{folder}/#{file}"
            end
            content << app.read_asset_file(file, type)
          end


          unless assets_opts[:concat_only]
            begin
              require 'yuicompressor'
              content = YUICompressor.send("compress_#{type}", content, :munge => true)
            rescue LoadError
              # yuicompressor not available, just use concatenated, uncompressed output
            end
          end

          key = "type#{".#{folder}" unless type == folder}"
          unique_id = assets_opts[:unique_ids][key] = Digest::SHA1.hexdigest(content)
          path = "#{assets_opts.values_at(:compiled_path, :"#{type}_folder", :compiled_name).join('/')}#{".#{folder}" unless type == folder}.#{unique_id}.#{type}"
          File.open(path, 'wb'){|f| f.write(content)}
          [key, unique_id]
        end
      end

      module InstanceMethods
        # This will ouput the files with the appropriate tags
        def assets(folder, options = {})
          assets_opts = self.class.assets_opts
          attrs   = options.map{|k,v| "#{k}=\"#{v}\""}.join(' ')
          if folder.is_a? Array
            folder_path = ".#{folder}"
          else
            folder  = [folder]
          end
          type    = folder.first
          if type.to_s == 'js'
            tag_start = "<script type=\"text/javascript\" #{attrs} src=\"/#{assets_opts[:prefix]}#{assets_opts[:"#{type}_folder"]}/"
            tag_end = ".#{type}\"></script>"
          else
            tag_start = "<link rel=\"stylesheet\" #{attrs} href=\"/#{assets_opts[:prefix]}#{assets_opts[:"#{type}_folder"]}/"
            tag_end = ".#{type}\" />"
          end

          # Create a tag for each individual file
          if assets_opts[:compiled]
            # Generate unique url so middleware knows
            # to check for # compile/concat
            "#{tag_start}#{assets_opts[:compiled_name]}#{folder_path}.#{assets_opts["#{type}#{folder_segment}"]}#{tag_end}"
          else
            files = (folder.length == 1 ? assets_opts[:"#{folder[0]}"] : \
                    assets_opts[:"#{folder[0]}"][:"#{folder[1]}"])

            files.map do |file|
              # This allows you to do things like:
              # assets_opts[:css] = ['app', './bower/jquery/jquery-min.js']
              file.gsub!(/\./, '$2E')
              "#{tag_start}#{file}#{tag_end}"
            end.join("\n")
          end
        end

        def render_asset(file, type)
          # convert back url safe to period
          file.gsub!(/(\$2E|%242E)/, '.')

          if self.class.assets_opts[:compiled]
            folder = file.split('/')[1].split('-', 2)
            path = "#{self.class.assets_opts.values_at(:compiled_path, :"#{type}_folder", :compiled_name).join('/')}#{".#{folder[1]}" if folder.length > 1}.#{type}"
            File.read(path)
          else
            read_asset_file file, type
          end
        end

        def read_asset_file(file, type)
          assets_opts = self.class.assets_opts

          # set the current engine
          engine = assets_opts[:"#{type}_engine"]

          # set the current folder
          folder = assets_opts[:"#{type}_folder"]

          # If it's not a parent directory append the full path
          if file !~ /\A\.\//
            file = "#{assets_opts[:path]}/#{folder}/#{file}"
          end

          if File.exist?("#{file}.#{engine}")
            # render via tilt
            render(:path => "#{file}.#{engine}")
          elsif File.exist?("#{file}.#{type}")
            # read file directly
            File.read("#{file}.#{type}")
          elsif file =~ /\.#{type}\z/
            File.read(file)
          else
            render(:path => file)
          end
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
            response.headers.merge!(self.class.assets_opts[:"#{type}_headers"])
            scope.render_asset(file, type)
          end
        end
      end
    end

    register_plugin(:assets, Assets)
  end
end
