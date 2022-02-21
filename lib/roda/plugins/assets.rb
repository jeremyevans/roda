# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The assets plugin adds support for rendering your CSS and javascript
    # asset files on the fly in development, and compiling them
    # to a single, compressed file in production.
    #
    # This uses the render plugin for rendering the assets, and the render
    # plugin uses tilt internally, so you can use any template engine
    # supported by tilt for your assets.  Tilt ships with support for
    # the following asset template engines, assuming the necessary libraries
    # are installed:
    #
    # css :: Less, Sass, Scss
    # js :: CoffeeScript
    #
    # You can also use opal as a javascript template engine, assuming it is
    # installed.
    #
    # == Usage
    #
    # When loading the plugin, use the :css and :js options
    # to set the source file(s) to use for CSS and javascript assets:
    #
    #   plugin :assets, css: 'some_file.scss', js: 'some_file.coffee'
    #
    # This will look for the following files:
    #
    #   assets/css/some_file.scss
    #   assets/js/some_file.coffee
    #
    # The values for the :css and :js options can be arrays to load multiple
    # files. If you want to change the paths where asset files are stored, see the
    # Options section below.
    #
    # === Serving
    #
    # In your routes, call the +r.assets+ method to add a route to your assets,
    # which will make your app serve the rendered assets:
    #
    #   route do |r|
    #     r.assets
    #   end
    #
    # You should generally call +r.assets+ inside the route block itself, and not
    # under any branches of the routing tree.
    #
    # === Views
    #
    # In your layout view, use the assets method to add links to your CSS and
    # javascript assets:
    #
    #   <%= assets(:css) %>
    #   <%= assets(:js) %>
    #
    # You can add attributes to the tags by using an options hash:
    #
    #   <%= assets(:css, media: 'print') %>
    #
    # The assets method will respect the application's +:add_script_name+ option,
    # if it set it will automatically prefix the path with the +SCRIPT_NAME+ for
    # the request.
    #
    # == Asset Paths
    #
    # If you just want the paths rather than the full tags, you can use
    # assets_paths instead. This will return an array of the sources that
    # the assets function would have put into tags:
    #
    #   assets_paths(:css)
    #   # => ["/assets/css/foo.css", "/assets/css/app.css"]
    #
    # If compilation is turned on, it will return the path to the compiled
    # asset:
    #
    #   assets_paths(:css)
    #   # => ["/assets/app.5e7b06baa1a514d8473b0eca514b806c201073b9.css"]
    #
    # == Asset Groups
    #
    # The asset plugin supports groups for the cases where you have different
    # css/js files for your front end and back end.  To use asset groups, you
    # pass a hash for the :css and/or :js options:
    #
    #   plugin :assets, css: {frontend: 'some_frontend_file.scss',
    #                         backend: 'some_backend_file.scss'}
    #
    # This expects the following directory structure for your assets:
    #
    #   assets/css/frontend/some_frontend_file.scss
    #   assets/css/backend/some_backend_file.scss
    #
    # If you do not want to force that directory structure when using
    # asset groups, you can use the <tt>group_subdirs: false</tt> option.
    #
    # In your view code use an array argument in your call to assets:
    #
    #   <%= assets([:css, :frontend]) %>
    #
    # === Nesting
    #
    # Asset groups also support nesting, though that should only be needed
    # in fairly large applications.  You can use a nested hash when loading
    # the plugin:
    #
    #   plugin :assets,
    #     css: {frontend: {dashboard: 'some_frontend_file.scss'}}
    #
    # and an extra entry per nesting level when creating the tags.
    #
    #   <%= assets([:css, :frontend, :dashboard]) %>
    #
    # == Caching
    #
    # The assets plugin uses the caching plugin internally, and will set the
    # Last-Modified header to the modified timestamp of the asset source file
    # when rendering the asset.
    #
    # If you have assets that include other asset files, such as using @import
    # in a sass file, you need to specify the dependencies for your assets so
    # that the assets plugin will correctly pick up changes.  You can do this
    # using the :dependencies option to the plugin, which takes a hash where
    # the keys are paths to asset files, and values are arrays of paths to
    # dependencies of those asset files:
    #
    #   app.plugin :assets,
    #     dependencies: {'assets/css/bootstrap.scss'=>Dir['assets/css/bootstrap/' '**/*.scss']}
    #
    # == Asset Compilation
    #
    # In production, you are generally going to want to compile your assets
    # into a single file, with you can do by calling compile_assets after
    # loading the plugin:
    #
    #   plugin :assets, css: 'some_file.scss', js: 'some_file.coffee'
    #   compile_assets
    #
    # After calling compile_assets, calls to assets in your views will default
    # to a using a single link each to your CSS and javascript compiled asset
    # files.  By default the compiled files are written to the public directory,
    # so that they can be served by the webserver.
    #
    # === Asset Compression
    #
    # If you have the yuicompressor gem installed and working, it will be used
    # automatically to compress your javascript and css assets.  For javascript
    # assets, if yuicompressor is not available, the plugin will check for
    # closure_compiler, uglifier, and minjs and use the first one that works.
    # If no compressors are available, the assets will just be concatenated
    # together and not compressed during compilation.  You can use the
    # :css_compressor and :js_compressor options to specify the compressor to use.
    #
    # It is also possible to use the built-in compression options in the CSS or JS
    # compiler, assuming the compiler supports such options.  For example, with
    # sass/sassc, you can use:
    #
    #   plugin :assets,
    #     css_opts: {style: :compressed}
    #
    # === Source Maps (CSS)
    #
    # The assets plugin does not have direct support for source maps, so it is
    # recommended you use embedded source maps if supported by the CSS compiler.
    # For sass/sassc, you can use:
    #
    #   plugin :assets,
    #     css_opts: {:source_map_embed=>true, source_map_contents: true, source_map_file: "."}
    #
    # === With Asset Groups
    #
    # When using asset groups, a separate compiled file will be produced per
    # asset group.
    #
    # === Unique Asset Names
    #
    # When compiling assets, a unique name is given to each asset file, using the
    # a SHA1 hash of the content of the file.  This is done so that clients do
    # not attempt to use cached versions of the assets if the asset has changed.
    #
    # === Serving
    #
    # When compiling assets, +r.assets+ will serve the compiled asset
    # files.  However, it is recommended to have the main webserver (e.g. nginx)
    # serve the compiled files, instead of relying on the application.
    #
    # Assuming you are using compiled assets in production mode that are served
    # by the webserver, you can remove the serving of them by the application:
    #
    #   route do |r|
    #     r.assets unless ENV['RACK_ENV'] == 'production'
    #   end
    #
    # If you do have the application serve the compiled assets, it will use the
    # Last-Modified header to make sure that clients do not redownload compiled
    # assets that haven't changed.
    #
    # === Asset Precompilation
    #
    # If you want to precompile your assets, so they do not need to be compiled
    # every time you boot the application, you can provide a :precompiled option
    # when loading the plugin.  The value of this option should be the filename
    # where the compiled asset metadata is stored.
    #
    # If the compiled asset metadata file does not exist when the assets plugin
    # is loaded, the plugin will run in non-compiled mode.  However, when you call
    # compile_assets, it will write the compiled asset metadata file after
    # compiling the assets.
    #
    # If the compiled asset metadata file already exists when the assets plugin
    # is loaded, the plugin will read the file to get the compiled asset metadata,
    # and it will run in compiled mode, assuming that the compiled asset files
    # already exist.
    #
    # ==== On Heroku
    #
    # Heroku supports precompiling the assets when using Roda.  You just need to
    # add an assets:precompile task, similar to this:
    #
    #   namespace :assets do
    #     desc "Precompile the assets"
    #     task :precompile do
    #       require './app'
    #       App.compile_assets
    #     end
    #   end
    #
    # == Postprocessing
    #
    # If you pass a callable object to the :postprocessor option, it will be called
    # before an asset is served.
    # If the assets are to be compiled, the object will be called at compilation time.
    #
    # It is passed three arguments; the name of the asset file, the type of the
    # asset file (which is a symbol, either :css or :js), and the asset contents.
    #
    # It should return the new content for the asset.
    #
    # You can use this to call Autoprefixer on your CSS:
    #
    #   plugin :assets, {
    #     css: [ 'style.scss' ],
    #     postprocessor: lambda do |file, type, content|
    #       type == :css ? AutoprefixerRails.process(content).css : content
    #     end
    #   }
    #
    # == External Assets/Assets from Gems
    #
    # The assets plugin only supports loading assets files underneath the assets
    # path.  You cannot pass an absolute path to an asset file and have it
    # work.  If you would like to reference asset files that are outside the assets
    # path, you have the following options:
    #
    # * Copy, hard link, or symlink the external assets files into the assets path.
    # * Use tilt-indirect or another method of indirection (such as an erb template that loads
    #   the external asset file) so that a file inside the assets path can reference files
    #   outside the assets path.
    #
    # == Plugin Options
    #
    # :add_suffix :: Whether to append a .css or .js extension to asset routes in non-compiled mode
    #                (default: false)
    # :compiled_asset_host :: The asset host to use for compiled assets.  Should include the protocol
    #                         as well as the host (e.g. "https://cdn.example.com", "//cdn.example.com")
    # :compiled_css_dir :: Directory name in which to store the compiled css file,
    #                      inside :compiled_path (default: nil)
    # :compiled_css_route :: Route under :prefix for compiled css assets (default: :compiled_css_dir)
    # :compiled_js_dir :: Directory name in which to store the compiled javascript file,
    #                     inside :compiled_path (default: nil)
    # :compiled_js_route :: Route under :prefix for compiled javscript assets (default: :compiled_js_dir)
    # :compiled_name :: Compiled file name prefix (default: 'app')
    # :compiled_path:: Path inside public folder in which compiled files are stored (default: :prefix)
    # :concat_only :: Whether to just concatenate instead of concatenating
    #                 and compressing files (default: false)
    # :css_compressor :: Compressor to use for compressing CSS, either :yui, :none, or nil (the default, which will try
    #                    :yui if available, but not fail if it is not available)
    # :css_dir :: Directory name containing your css source, inside :path (default: 'css')
    # :css_headers :: A hash of additional headers for your rendered css files
    # :css_opts :: Template options to pass to the render plugin (via :template_opts) when rendering css assets
    # :css_route :: Route under :prefix for css assets (default: :css_dir)
    # :dependencies :: A hash of dependencies for your asset files.  Keys should be paths to asset files,
    #                  values should be arrays of paths your asset files depends on.  This is used to
    #                  detect changes in your asset files.
    # :early_hints :: Automatically send early hints for all assets.  Requires the early_hints plugin.
    # :group_subdirs :: Whether a hash used in :css and :js options requires the assets for the
    #                   related group are contained in a subdirectory with the same name (default: true)
    # :gzip :: Store gzipped compiled assets files, and serve those to clients who accept gzip encoding.
    # :headers :: A hash of additional headers for both js and css rendered files
    # :js_compressor :: Compressor to use for compressing javascript, either :yui, :closure, :uglifier, :minjs,
    #                   :none, or nil (the default, which will try :yui, :closure, :uglifier, then :minjs, but
    #                   not fail if any of them is not available)
    # :js_dir :: Directory name containing your javascript source, inside :path (default: 'js')
    # :js_headers :: A hash of additional headers for your rendered javascript files
    # :js_opts :: Template options to pass to the render plugin (via :template_opts) when rendering javascript assets
    # :js_route :: Route under :prefix for javascript assets (default: :js_dir)
    # :path :: Path to your asset source directory (default: 'assets').   Relative
    #          paths will be considered relative to the application's :root option.
    # :postprocessor :: A block which should accept three arguments (asset name, asset type,
    #                   content). This block can be used to hook into the asset system and
    #                   make your own modifications before the asset is served. If the asset
    #                   is to be compiled, the block is called at compile time.
    # :prefix :: Prefix for assets path in your URL/routes (default: 'assets')
    # :precompiled :: Path to the compiled asset metadata file.  If the file exists, will use compiled
    #                 mode using the metadata in the file.  If the file does not exist, will use
    #                 non-compiled mode, but will write the metadata to the file if compile_assets is called.
    # :public :: Path to your public folder, in which compiled files are placed (default: 'public').  Relative
    #            paths will be considered relative to the application's :root option.
    # :relative_paths :: Use relative paths instead of absolute paths when setting up link and script tags for
    #                    assets.
    # :sri :: Enables subresource integrity when setting up references to compiled assets. The value should be
    #         :sha256, :sha384, or :sha512 depending on which hash algorithm you want to use.  This changes the
    #         hash algorithm that Roda will use when naming compiled asset files. The default is :sha256, you
    #         can use nil to disable subresource integrity.
    # :timestamp_paths :: Include the timestamp of assets in asset paths in non-compiled mode. Doing this can
    #                     slow down development requests due to additional requests to get last modified times,
    #                     but it will make sure the paths change in development when there are modifications,
    #                     which can fix issues when using a caching proxy in non-compiled mode. This can also
    #                     be specified as a string to use that string to separate the timestamp from the asset.
    #                     By default, <tt>/</tt> is used as the separator if timestamp paths are enabled.
    module Assets
      DEFAULTS = {
        :compiled_name    => 'app'.freeze,
        :js_dir           => 'js'.freeze,
        :css_dir          => 'css'.freeze,
        :prefix           => 'assets'.freeze,
        :concat_only      => false,
        :compiled         => false,
        :add_suffix       => false,
        :early_hints      => false,
        :timestamp_paths  => false,
        :group_subdirs    => true,
        :compiled_css_dir => nil,
        :compiled_js_dir  => nil,
        :sri              => :sha256
      }.freeze

      # Internal exception raised when a compressor cannot be found
      CompressorNotFound = Class.new(RodaError)

      # Load the render, caching, and h plugins, since the assets plugin
      # depends on them.
      def self.load_dependencies(app, opts = OPTS)
        app.plugin :render
        app.plugin :caching
        app.plugin :h

        if opts[:relative_paths]
          app.plugin :relative_path
        end
      end

      # Setup the options for the plugin.  See the Assets module RDoc
      # for a description of the supported options.
      def self.configure(app, opts = {})
        if app.assets_opts
          prev_opts = app.assets_opts[:orig_opts]
          orig_opts = app.assets_opts[:orig_opts].merge(opts)
          [:headers, :css_headers, :js_headers, :css_opts, :js_opts, :dependencies].each do |s|
            if prev_opts[s]
              if opts[s]
                orig_opts[s] = prev_opts[s].merge(opts[s])
              else
                orig_opts[s] = prev_opts[s].dup
              end
            end
          end
          app.opts[:assets] = orig_opts.dup
          app.opts[:assets][:orig_opts] = orig_opts
        else
          app.opts[:assets] = opts.dup
          app.opts[:assets][:orig_opts] = opts
        end
        opts = app.opts[:assets]
        opts[:path] = app.expand_path(opts[:path]||"assets").freeze
        opts[:public] = app.expand_path(opts[:public]||"public").freeze

        # Combine multiple values into a path, ignoring trailing slashes
        j = lambda do |*v|
          opts.values_at(*v).
            reject{|s| s.to_s.empty?}.
            map{|s| s.chomp('/')}.
            join('/').freeze
        end

        # Same as j, but add a trailing slash if not empty
        sj = lambda do |*v|
          s = j.call(*v)
          s.empty? ? s : (s + '/').freeze
        end

        if opts[:precompiled] && !opts[:compiled] && ::File.exist?(opts[:precompiled])
          require 'json'
          opts[:compiled] = app.send(:_precompiled_asset_metadata, opts[:precompiled])
        end

        if opts[:early_hints]
          app.plugin :early_hints
        end

        if opts[:timestamp_paths] && !opts[:timestamp_paths].is_a?(String)
          opts[:timestamp_paths] = '/'
        end

        DEFAULTS.each do |k, v|
          opts[k] = v unless opts.has_key?(k)
        end

        [
         [:compiled_path, :prefix],
         [:js_route, :js_dir],
         [:css_route, :css_dir],
         [:compiled_js_route, :compiled_js_dir],
         [:compiled_css_route, :compiled_css_dir]
        ].each do |k, v|
          opts[k]  = opts[v] unless opts.has_key?(k)
        end

        [:css_headers, :js_headers, :css_opts, :js_opts, :dependencies].each do |s|
          opts[s] ||= {}
        end

        expanded_deps = opts[:expanded_dependencies] = {}
        opts[:dependencies].each do |file, deps|
          expanded_deps[File.expand_path(file)] = Array(deps)
        end

        if headers = opts[:headers]
          opts[:css_headers] = headers.merge(opts[:css_headers])
          opts[:js_headers]  = headers.merge(opts[:js_headers])
        end
        opts[:css_headers]['Content-Type'] ||= "text/css; charset=UTF-8".freeze
        opts[:js_headers]['Content-Type']  ||= "application/javascript; charset=UTF-8".freeze

        [:css_headers, :js_headers, :css_opts, :js_opts, :dependencies, :expanded_dependencies].each do |s|
          opts[s].freeze
        end
        [:headers, :css, :js].each do |s|
          opts[s].freeze if opts[s]
        end

        # Used for reading/writing files
        opts[:js_path]           = sj.call(:path, :js_dir)
        opts[:css_path]          = sj.call(:path, :css_dir)
        opts[:compiled_js_path]  = j.call(:public, :compiled_path, :compiled_js_dir, :compiled_name)
        opts[:compiled_css_path] = j.call(:public, :compiled_path, :compiled_css_dir, :compiled_name)

        # Used for URLs/routes
        opts[:js_prefix]           = sj.call(:prefix, :js_route)
        opts[:css_prefix]          = sj.call(:prefix, :css_route)
        opts[:compiled_js_prefix]  = j.call(:prefix, :compiled_js_route, :compiled_name)
        opts[:compiled_css_prefix] = j.call(:prefix, :compiled_css_route, :compiled_name)
        opts[:js_suffix]           = (opts[:add_suffix] ? '.js' : '').freeze
        opts[:css_suffix]          = (opts[:add_suffix] ? '.css' : '').freeze

        opts.freeze
      end

      module ClassMethods
        # Return the assets options for this class.
        def assets_opts
          opts[:assets]
        end

        # Compile options for the given asset type.  If no asset_type
        # is given, compile both the :css and :js asset types.  You
        # can specify an array of types (e.g. [:css, :frontend]) to
        # compile assets for the given asset group.
        def compile_assets(type=nil)
          require 'fileutils'

          unless assets_opts[:compiled]
            opts[:assets] = assets_opts.merge(:compiled => _compiled_assets_initial_hash).freeze
          end

          if type == nil
            _compile_assets(:css)
            _compile_assets(:js)
          else
            _compile_assets(type)
          end

          if precompile_file = assets_opts[:precompiled]
            require 'json'
            ::FileUtils.mkdir_p(File.dirname(precompile_file))
            tmp_file = "#{precompile_file}.tmp"
            ::File.open(tmp_file, 'wb'){|f| f.write((opts[:json_serializer] || :to_json.to_proc).call(assets_opts[:compiled]))}
            ::File.rename(tmp_file, precompile_file)
          end

          assets_opts[:compiled]
        end

        private

        # The initial hash to use to store compiled asset metadata.
        def _compiled_assets_initial_hash
          {}
        end

        # Internals of compile_assets, handling recursive calls for loading
        # all asset groups under the given type.
        def _compile_assets(type)
          type, *dirs = type if type.is_a?(Array)
          dirs ||= []
          files = assets_opts[type]
          dirs.each{|d| files = files[d]}

          case files
          when Hash
            files.each_key{|dir| _compile_assets([type] + dirs + [dir])}
          else
            files = Array(files)
            compile_assets_files(files, type, dirs) unless files.empty?
          end
        end

        # The precompiled asset metadata stored in the given file
        def _precompiled_asset_metadata(file)
          (opts[:json_parser] || ::JSON.method(:parse)).call(::File.read(file))
        end

        # Compile each array of files for the given type into a single
        # file.  Dirs should be an array of asset group names, if these
        # are files in an asset group.
        def compile_assets_files(files, type, dirs)
          dirs = nil if dirs && dirs.empty?
          o = assets_opts
          app = allocate

          content = files.map do |file|
            file = "#{dirs.join('/')}/#{file}" if dirs && o[:group_subdirs]
            file = "#{o[:"#{type}_path"]}#{file}"
            app.read_asset_file(file, type)
          end.join("\n")

          unless o[:concat_only]
            content = compress_asset(content, type)
          end

          suffix = ".#{dirs.join('.')}" if dirs
          key = "#{type}#{suffix}"
          unique_id = o[:compiled][key] = asset_digest(content)
          path = "#{o[:"compiled_#{type}_path"]}#{suffix}.#{unique_id}.#{type}"
          ::FileUtils.mkdir_p(File.dirname(path))
          ::File.open(path, 'wb'){|f| f.write(content)}

          if o[:gzip]
            require 'zlib'
            Zlib::GzipWriter.open("#{path}.gz") do |gz|
              gz.write(content)
            end
          end

          nil
        end

        # Compress the given content for the given type by using the
        # configured compressor, or trying the supported compressors.
        def compress_asset(content, type)
          case compressor = assets_opts[:"#{type}_compressor"]
          when :none
            return content
          when nil
            # default, try different compressors
          else
            # Allow calling private compress methods
            return send("compress_#{type}_#{compressor}", content)
          end

          compressors = if type == :js
            [:yui, :closure, :uglifier, :minjs]
          else
            [:yui]
          end

          compressors.each do |comp|
            begin
            # Allow calling private compress methods
              if c = send("compress_#{type}_#{comp}", content)
                return c
              end
            rescue LoadError, CompressorNotFound
            end
          end

          content
        end

        # Compress the CSS using YUI Compressor, requires java runtime
        def compress_css_yui(content)
          compress_yui(content, :compress_css)
        end

        # Compress the JS using Google Closure Compiler, requires java runtime
        def compress_js_closure(content)
          require 'closure-compiler'

          begin
            ::Closure::Compiler.new.compile(content)
          rescue ::Closure::Error => e
            raise CompressorNotFound, "#{e.class}: #{e.message}", e.backtrace
          end
        end

        # Compress the JS using MinJS, a pure ruby compressor
        def compress_js_minjs(content)
          require 'minjs'
          Minjs::Compressor::Compressor.new(:debug => false).compress(content).to_js
        end

        # Compress the JS using Uglifier, requires javascript runtime
        def compress_js_uglifier(content)
          begin
            require 'uglifier'
          rescue => e
            # :nocov:
            raise CompressorNotFound, "#{e.class}: #{e.message}", e.backtrace
            # :nocov:
          end

          Uglifier.compile(content)
        end

        # Compress the CSS using YUI Compressor, requires java runtime
        def compress_js_yui(content)
          compress_yui(content, :compress_js)
        end

        # Compress the CSS/JS using YUI Compressor, requires java runtime
        def compress_yui(content, meth)
          require 'yuicompressor'
          ::YUICompressor.public_send(meth, content, :munge => true)
        rescue ::Errno::ENOENT => e
          raise CompressorNotFound, "#{e.class}: #{e.message}", e.backtrace
        end

        # Return a unique id for the given content.  By default, uses the
        # SHA256 hash of the content.  This method can be overridden to use
        # a different digest type or to return a static string if you don't
        # want to use a unique value.
        def asset_digest(content)
          algo = assets_opts[:sri] || :sha256
          digest = begin
            require 'openssl'
            ::OpenSSL::Digest
          # :nocov:
          rescue LoadError
            require 'digest/sha2'
            ::Digest
          # :nocov:
          end
          digest.const_get(algo.to_s.upcase).hexdigest(content)
        end
      end

      module InstanceMethods
        # Return an array of paths for the given asset type and optionally
        # asset group. See the assets function documentation for details.
        def assets_paths(type)
          o = self.class.assets_opts
          if type.is_a?(Array)
            ltype, *dirs = type
          else
            ltype = type
          end
          stype = ltype.to_s

          url_prefix = request.script_name if self.class.opts[:add_script_name]
          relative_paths = o[:relative_paths]

          paths = if o[:compiled]
            relative_paths = false if o[:compiled_asset_host]
            if ukey = _compiled_assets_hash(type, true)
              ["#{o[:compiled_asset_host]}#{url_prefix}/#{o[:"compiled_#{stype}_prefix"]}.#{ukey}.#{stype}"]
            else
              []
            end
          else
            asset_dir = o[ltype]
            if dirs && !dirs.empty?
              dirs.each{|f| asset_dir = asset_dir[f]}
              prefix = "#{dirs.join('/')}/" if o[:group_subdirs]
            end
            Array(asset_dir).map do |f|
              if ts = o[:timestamp_paths]
                mtime = asset_last_modified(File.join(o[:"#{stype}_path"], *[prefix, f].compact))
                mtime = "#{sprintf("%i%06i", mtime.to_i, mtime.usec)}#{ts}"
              end
              "#{url_prefix}/#{o[:"#{stype}_prefix"]}#{mtime}#{prefix}#{f}#{o[:"#{stype}_suffix"]}"
            end
          end

          if relative_paths
            paths.map! do |path|
              "#{relative_prefix}#{path}"
            end
          end

          paths
        end

        # Return a string containing html tags for the given asset type.
        # This will use a script tag for the :js type and a link tag for
        # the :css type.
        #
        # To return the tags for a specific asset group, use an array for
        # the type, such as [:css, :frontend].
        #
        # When the assets are not compiled, this will result in a separate
        # tag for each asset file.  When the assets are compiled, this will
        # result in a single tag to the compiled asset file.
        def assets(type, attrs = OPTS)
          ltype = type.is_a?(Array) ? type[0] : type

          o = self.class.assets_opts
          if o[:compiled] && (algo = o[:sri]) && (hash = _compiled_assets_hash(type))
            attrs = Hash[attrs]
            attrs[:integrity] = "#{algo}-#{h([[hash].pack('H*')].pack('m').tr("\n", ''))}"
          end

          unless attrs[:type]
            attrs = Hash[attrs]
            attrs[:type] = "text/javascript"
          end

          attrs = attrs.map{|k,v| "#{k}=\"#{h(v)}\""}.join(' ')

          if ltype == :js
            tag_start = "<script #{attrs} src=\""
            tag_end = "\"></script>"
          else
            tag_start = "<link rel=\"stylesheet\" #{attrs} href=\""
            tag_end = "\" />"
          end

          paths = assets_paths(type)
          if o[:early_hints]
            early_hint_as = ltype == :js ? 'script' : 'style'
            send_early_hints('Link'=>paths.map{|p| "<#{p}>; rel=preload; as=#{early_hint_as}"}.join("\n"))
          end
          paths.map{|p| "#{tag_start}#{h(p)}#{tag_end}"}.join("\n")
        end

        # Render the asset with the given filename.  When assets are compiled,
        # or when the file is already of the given type (no rendering necessary),
        # this returns the contents of the compiled file.
        # When assets are not compiled and the file is not already in the same format,
        # this will render the asset using the render plugin.
        # In both cases, if the file has not been modified since the last request,
        # this will return a 304 response.
        def render_asset(file, type)
          o = self.class.assets_opts
          if o[:compiled]
            file = "#{o[:"compiled_#{type}_path"]}#{file}"

            if o[:gzip] && env['HTTP_ACCEPT_ENCODING'] =~ /\bgzip\b/
              @_response['Content-Encoding'] = 'gzip'
              file += '.gz'
            end

            check_asset_request(file, type, ::File.stat(file).mtime)
            ::File.read(file)
          else
            file = "#{o[:"#{type}_path"]}#{file}"
            check_asset_request(file, type, asset_last_modified(file))
            read_asset_file(file, type)
          end
        end

        # Return the content of the file if it is already of the correct type.
        # Otherwise, render the file using the render plugin.  +file+ should be
        # the relative path to the file from the current directory.
        def read_asset_file(file, type)
          o = self.class.assets_opts

          content = if file.end_with?(".#{type}")
            ::File.read(file)
          else
            render_asset_file(file, :template_opts=>o[:"#{type}_opts"], :dependencies=>o[:expanded_dependencies][file])
          end

          o[:postprocessor] ? o[:postprocessor].call(file, type, content) : content
        end

        private

        def _compiled_assets_hash(type, return_ukey=false)
          compiled = self.class.assets_opts[:compiled]
          type, *dirs = type if type.is_a?(Array)
          stype = type.to_s

          if dirs && !dirs.empty?
            key = dirs.join('.')
            ckey = "#{stype}.#{key}"
            if hash = ukey = compiled[ckey]
              ukey = "#{key}.#{ukey}"
            end
          else
            hash = ukey = compiled[stype]
          end

          return_ukey ? ukey : hash
        end

        # Return when the file was last modified.  If the file depends on any
        # other files, check the modification times of all dependencies and
        # return the maximum.
        def asset_last_modified(file)
          if deps = self.class.assets_opts[:expanded_dependencies][file]
            ([file] + Array(deps)).map{|f| ::File.stat(f).mtime}.max
          else
            ::File.stat(file).mtime
          end
        end

        # If the asset hasn't been modified since the last request, return
        # a 304 response immediately.  Otherwise, add the appropriate
        # type-specific headers.
        def check_asset_request(file, type, mtime)
          @_request.last_modified(mtime)
          @_response.headers.merge!(self.class.assets_opts[:"#{type}_headers"])
        end

        # Render the given asset file using the render plugin, with the given options.
        # +file+ should be the relative path to the file from the current directory.
        def render_asset_file(file, options)
          render_template({:path => file}, options)
        end
      end

      module RequestClassMethods
        # An array of asset type strings and regexps for that type, for all asset types
        # handled.
        def assets_matchers
          @assets_matchers ||= [:css, :js].map do |t|
            if regexp = assets_regexp(t)
              [t, regexp].freeze
            end
          end.compact.freeze
        end

        private

        # A string for the asset filename for the asset type, key, and digest.
        def _asset_regexp(type, key, digest)
          "#{key.sub(/\A#{type}/, '')}.#{digest}.#{type}"
        end

        # The regexp matcher to use for the given type.  This handles any asset groups
        # for the asset types.
        def assets_regexp(type)
          o = roda_class.assets_opts
          if compiled = o[:compiled]
            assets = compiled.
              select{|k,_| k =~ /\A#{type}/}.
              map{|k, md| _asset_regexp(type, k, md)}
            return if assets.empty?
            /#{o[:"compiled_#{type}_prefix"]}(#{Regexp.union(assets)})/
          else
            return unless assets = o[type]
            assets = unnest_assets_hash(assets)
            ts = o[:timestamp_paths]
            /#{o[:"#{type}_prefix"]}#{"\\d+#{ts}" if ts}(#{Regexp.union(assets.uniq)})#{o[:"#{type}_suffix"]}/
          end
        end

        # Recursively unnested the given assets hash, returning a single array of asset
        # files for the given.
        def unnest_assets_hash(h)
          case h
          when Hash
            h.map do |k,v|
              assets = unnest_assets_hash(v)
              assets = assets.map{|x| "#{k}/#{x}"} if roda_class.assets_opts[:group_subdirs]
              assets
            end.flatten(1)
          else
            Array(h)
          end
        end
      end

      module RequestMethods
        # Render the matching asset if this is a GET request for a supported asset.
        def assets
          if is_get?
            self.class.assets_matchers.each do |type, matcher|
              is matcher do |file|
                scope.render_asset(file, type)
              end
            end
            nil
          end
        end
      end
    end

    register_plugin(:assets, Assets)
  end
end
