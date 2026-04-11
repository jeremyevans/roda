# frozen-string-literal: true

require 'digest/sha2'

class Roda
  module RodaPlugins
    # The hash_public plugin adds a +hash_path+ method for constructing
    # content-hash-based paths, and a +r.hash_public+ routing method to serve
    # static files from a directory (using the public plugin).  This plugin is
    # useful when you want to modify the path to static files when the content
    # of the file changes, ensuring that requests for the static file will not
    # be cached.
    #
    # Unlike the timestamp_public plugin, which uses file modification times,
    # hash_public uses a SHA256 digest of the file content.  This makes paths
    # stable across different build environments (e.g. Docker images built in
    # CI/CD pipelines), where file modification times may vary even when the
    # file content has not changed.
    #
    # Note that while this plugin will not serve files outside of the public
    # directory, for performance reasons it does not check the path of the file
    # is inside the public directory when computing the content hash.  If the
    # +hash_path+ method is called with untrusted input, it is possible for an
    # attacker to read the content hash of any file on the file system.
    #
    # This plugin caches the digest of file content on first read. That means
    # if you change the file after that, it will continue to show the old hash.
    # This can cause problems in development mode if you are modifying the
    # content of files served by the plugin.
    #
    # Examples:
    #
    #   # Use public folder as location of files, and static as the path prefix
    #   plugin :hash_public
    #
    #   # Use /path/to/app/static as location of files, and public as the path prefix
    #   opts[:root] = '/path/to/app'
    #   plugin :hash_public, root: 'static', prefix: 'public'
    #
    #   # Assuming public is the location of files, and static as the path prefix
    #   route do
    #     # Make GET /static/any-string/images/foo.png look for public/images/foo.png
    #     r.hash_public
    #
    #     r.get "example" do
    #       # "/static/sha256-url-safe-base64-encoded-file-digest-/images/foo.png"
    #       hash_path("images/foo.png")
    #     end
    #   end
    module HashPublic
      # Use options given to setup content-hash-based file serving.  The
      # following options are recognized by the plugin:
      #
      # :prefix :: The prefix for paths, before the hash segment
      # :length :: The number of characters of the digest to use in paths
      #            (default: full 43-character SHA256 URL safe base64 digest)
      #
      # The options given are also passed to the public plugin.
      def self.configure(app, opts = {})
        app.plugin :public, opts
        app.opts[:hash_public_prefix] = (opts[:prefix] || app.opts[:hash_public_prefix] || 'static').dup.freeze
        app.opts[:hash_public_length] = opts[:length] || app.opts[:hash_public_length]
        app.opts[:hash_public_mutex] ||= Mutex.new
        app.opts[:hash_public_cache] ||= {}
      end

      module InstanceMethods
        # Return a path to the static file that could be served by r.hash_public.
        # This does not check the file is inside the directory for performance
        # reasons, so this should not be called with untrusted input.
        def hash_path(file)
          opts = self.opts
          cache = opts[:hash_public_cache]
          mutex = opts[:hash_public_mutex]
          unless digest = mutex.synchronize{cache[file]}
            digest = ::Digest::SHA256.file(File.join(opts[:public_root], file)).base64digest
            digest.chomp!("=")
            digest.tr!("+/", "-_")
            if length = opts[:hash_public_length]
              digest = digest[0, length]
            end
            digest.freeze
            mutex.synchronize{cache[file] = digest}
          end
          "/#{opts[:hash_public_prefix]}/#{digest}/#{file}"
        end
      end

      module RequestMethods
        # Serve files from the public directory if the file exists,
        # it includes the hash_public prefix segment followed by
        # a string segment for the content hash, and this is a GET request.
        def hash_public
          if is_get?
            on roda_class.opts[:hash_public_prefix], String do |_|
              public
            end
          end
        end
      end
    end

    register_plugin(:hash_public, HashPublic)
  end
end
