# frozen-string-literal: true

require 'uri'

#
class Roda
  module RodaPlugins
    # The public plugin adds a +r.public+ routing method to serve static files
    # from a directory.
    #
    # The public plugin recognizes the application's :root option, and defaults to
    # using the +public+ subfolder of the application's +:root+ option.  If the application's
    # :root option is not set, it defaults to the +public+ folder in the working
    # directory.  Additionally, if a relative path is provided as the +:root+
    # option to the plugin, it will be considered relative to the application's
    # +:root+ option.
    #
    # Examples:
    #
    #   # Use public folder as location of files
    #   plugin :public
    #
    #   # Use /path/to/app/static as location of files
    #   opts[:root] = '/path/to/app'
    #   plugin :public, root: 'static'
    #
    #   # Assuming public is the location of files
    #   r.route do
    #     # Make GET /images/foo.png look for public/images/foo.png 
    #     r.public
    #
    #     # Make GET /static/images/foo.png look for public/images/foo.png
    #     r.on(:static) do
    #       r.public
    #     end
    #   end
    module Public
      SPLIT = Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)
      PARSER = URI::DEFAULT_PARSER

      # Use options given to setup a Rack::File instance for serving files. Options:
      # :default_mime :: The default mime type to use if the mime type is not recognized.
      # :gzip :: Whether to serve already gzipped files with a .gz extension for clients
      #          supporting gzipped transfer encoding.
      # :brotli :: Whether to serve already brotli-compressed files with a .br extension
      #            for clients supporting brotli transfer encoding.
      # :headers :: A hash of headers to use for statically served files
      # :root :: Use this option for the root of the public directory (default: "public")
      # :pretty_urls :: Whether to check for either /path/to/file.html or
      #                 /path/to/file/index.html for a URL of /path/to/file
      def self.configure(app, opts={})
        if opts[:root]
          app.opts[:public_root] = app.expand_path(opts[:root])
        elsif !app.opts[:public_root]
          app.opts[:public_root] = app.expand_path("public")
        end
        app.opts[:public_server] = ::Rack::File.new(app.opts[:public_root], opts[:headers]||{}, opts[:default_mime] || 'text/plain')
        app.opts[:public_gzip] = opts[:gzip]
        app.opts[:public_brotli] = opts[:brotli]
        app.opts[:public_pretty_urls] = opts[:pretty_urls]
      end

      module RequestMethods
        # Serve files from the public directory if the file exists and this is a GET request.
        def public
          public_serve_with(roda_class.opts[:public_server])
        end

        private

        # Return an array of segments for the given path, handling ..
        # and . components
        def public_path_segments(path)
          segments = []
            
          path.split(SPLIT).each do |seg|
            next if seg.empty? || seg == '.'
            seg == '..' ? segments.pop : segments << seg
          end

          if roda_class.opts[:public_pretty_urls]
            check_path = ::File.join(roda_class.opts[:public_root], *segments)
            unless ::File.file?(check_path)
              check_path = ::File.join(check_path, "index.html")
              if ::File.file?(check_path)
                segments << "index.html"
              elsif segments.size.positive?
                segments[-1] = "#{segments.last}.html"
              end
            end
          end

          segments
        end

        # Return whether the given path is a readable regular file.
        def public_file_readable?(path)
          ::File.file?(path) && ::File.readable?(path)
        rescue SystemCallError
          # :nocov:
          false
          # :nocov:
        end

        def public_serve_with(server)
          return unless is_get?
          path = PARSER.unescape(real_remaining_path)
          return if path.include?("\0")

          roda_opts = roda_class.opts
          path = ::File.join(server.root, *public_path_segments(path))

          public_serve_compressed(server, path, '.br', 'br') if roda_opts[:public_brotli]
          public_serve_compressed(server, path, '.gz', 'gzip') if roda_opts[:public_gzip]

          if public_file_readable?(path)
            halt public_serve(server, path)
          end
        end

        def public_serve_compressed(server, path, suffix, encoding)
          if env['HTTP_ACCEPT_ENCODING'] =~ /\b#{encoding}\b/
            compressed_path = path + suffix

            if public_file_readable?(compressed_path)
              res = public_serve(server, compressed_path)
              headers = res[1]

              unless res[0] == 304
                headers['Content-Type'] = ::Rack::Mime.mime_type(::File.extname(path), 'text/plain')
                headers['Content-Encoding'] = encoding
              end

              halt res
            end
          end
        end

        if ::Rack.release > '2'
          # Serve the given path using the given Rack::File server.
          def public_serve(server, path)
            server.serving(self, path)
          end
        else
          # :nocov:
          def public_serve(server, path)
            server = server.dup
            server.path = path
            server.serving(env)
          end
          # :nocov:
        end
      end
    end

    register_plugin(:public, Public)
  end
end
