# frozen-string-literal: true

require 'uri'

begin
  require 'rack/files'
rescue LoadError
  require 'rack/file'
end

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
    #   route do
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
      RACK_FILES = defined?(Rack::Files) ? Rack::Files : Rack::File
      ENCODING_MAP = {:zstd=>'zstd', :brotli=>'br', :gzip=>'gzip'}.freeze
      ENCODING_EXTENSIONS = {'br'=>'.br', 'gzip'=>'.gz', 'zstd'=>'.zst'}.freeze

      # simplecov:disable
      PARSER = defined?(::URI::RFC2396_PARSER) ? ::URI::RFC2396_PARSER : ::URI::DEFAULT_PARSER
      MATCH_METHOD = RUBY_VERSION >= '2.4' ? :match? : :match
      # simplecov:enable

      # Use options given to setup a Rack::File instance for serving files. Options:
      # :brotli :: Whether to serve already brotli-compressed files with a .br extension
      #            for clients supporting "br" transfer encoding.
      # :default_mime :: The default mime type to use if the mime type is not recognized.
      # :encodings :: An enumerable of pairs to handle accepted encodings.  The first
      #               element of the pair is the accepted encoding name (e.g. 'gzip'),
      #               and the second element of the pair is the file extension (e.g.
      #               '.gz'). This allows configuration of the order in which encodings 
      #               are tried, to prefer brotli to zstd for example, or to support
      #               encodings other than zstd, brotli, and gzip. This takes
      #               precedence over the :brotli, :gzip, and :zstd options if given.
      # :gzip :: Whether to serve already gzipped files with a .gz extension for clients
      #          supporting "gzip" transfer encoding.
      # :headers :: A hash of headers to use for statically served files
      # :root :: Use this option for the root of the public directory (default: "public")
      # :zstd :: Whether to serve already zstd-compressed files with a .zst extension
      #          for clients supporting "zstd" transfer encoding.
      def self.configure(app, opts={})
        if opts[:root]
          app.opts[:public_root] = app.expand_path(opts[:root])
        elsif !app.opts[:public_root]
          app.opts[:public_root] = app.expand_path("public")
        end
        app.opts[:public_server] = RACK_FILES.new(app.opts[:public_root], opts[:headers]||{}, opts[:default_mime] || 'text/plain')

        unless encodings = opts[:encodings]
          if ENCODING_MAP.any?{|k,| opts.has_key?(k)}
            encodings = ENCODING_MAP.map{|k, v| [v, ENCODING_EXTENSIONS[v]] if opts[k]}.compact
          end
        end
        encodings = (encodings || app.opts[:public_encodings] || EMPTY_ARRAY).map(&:dup).freeze
        encodings.each do |a|
          a << /\b#{a[0]}\b/
        end
        encodings.each(&:freeze)
        app.opts[:public_encodings] = encodings
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
            
          segments
        end

        # Return whether the given path is a readable regular file.
        def public_file_readable?(path)
          ::File.file?(path) && ::File.readable?(path)
        rescue SystemCallError
          # simplecov:disable
          false
          # simplecov:enable
        end

        def public_serve_with(server)
          return unless is_get?
          path = PARSER.unescape(real_remaining_path)
          return if path.include?("\0")

          roda_opts = roda_class.opts
          path = ::File.join(server.root, *public_path_segments(path))

          if accept_encoding = env['HTTP_ACCEPT_ENCODING']
            roda_opts[:public_encodings].each do |enc, ext, regexp|
              if regexp.send(MATCH_METHOD, accept_encoding)
                public_serve_compressed(server, path, ext, enc)
              end
            end
          end

          if public_file_readable?(path)
            s, h, b = public_serve(server, path)
            headers = response.headers
            headers.replace(h)
            halt [s, headers, b]
          end
        end

        # Serve the compressed file if it exists.  This should only
        # be called if the client will accept the related encoding.
        def public_serve_compressed(server, path, suffix, encoding)
          compressed_path = path + suffix

          if public_file_readable?(compressed_path)
            s, h, b = public_serve(server, compressed_path)
            headers = response.headers
            headers.replace(h)

            unless s == 304
              headers[RodaResponseHeaders::CONTENT_TYPE] = ::Rack::Mime.mime_type(::File.extname(path), 'text/plain')
              headers[RodaResponseHeaders::CONTENT_ENCODING] = encoding
            end

            halt [s, headers, b]
          end
        end

        if ::Rack.release > '2'
          # Serve the given path using the given Rack::Files server.
          def public_serve(server, path)
            server.serving(self, path)
          end
        else
          def public_serve(server, path)
            server = server.dup
            server.path = path
            server.serving(env)
          end
        end
      end
    end

    register_plugin(:public, Public)
  end
end
