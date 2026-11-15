# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The timestamp_public plugin adds a +timestamp_path+ method for constructing
    # timestamp paths, and a +r.timestamp_public+ routing method to serve static files
    # from a directory (using the public plugin).  This plugin is useful when you want
    # to modify the path to static files when the modify timestamp on the file changes,
    # ensuring proper cache busting after modifications to static files.
    #
    # Note that while this plugin will not serve files outside of the public directory,
    # for performance reasons it does not check the path of the file is inside the public
    # directory when getting the modify timestamp.  If the +timestamp_path+ method is
    # called with untrusted input, it is possible for an attacker to get the modify
    # timestamp for any file on the file system.
    #
    # Examples:
    #
    #   # Use public folder as location of files, and static as the path prefix
    #   plugin :timestamp_public
    #
    #   # Use /path/to/app/static as location of files, and public as the path prefix
    #   opts[:root] = '/path/to/app'
    #   plugin :public, root: 'static', prefix: 'public'
    #
    #   # Assuming public is the location of files, and static is the path prefix
    #   route do
    #     # Make GET /static/1238099123/images/foo.png look for public/images/foo.png 
    #     r.timestamp_public
    #
    #     r.get "example" do
    #       # "/static/1238099123/images/foo.png"
    #       timestamp_path("images/foo.png")
    #     end
    #   end
    module TimestampPublic
      def self.load_dependencies(app, opts=OPTS)
        app.plugin :public
      end

      # Use options given to setup timestamped file serving.  The following argument is
      # recognized by the plugin:
      #
      # :prefix :: The prefix for paths, before the timestamp segment
      #
      # The other arguments given are also passed to the public plugin.
      def self.configure(app, opts=(no_positional_opts = true; OPTS),
          prefix: opts[:prefix],
          **kw)
        RodaPlugins.check_keywords("the hash_public plugin", no_positional_opts, opts, OPTS)
        app.plugin :public, **opts.merge(kw)

        app.opts[:timestamp_public_prefix] = (prefix || app.timestamp_public_prefix || "static").dup.freeze
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :timestamp_public_prefix)
      end

      module InstanceMethods
        # Return a path to the static file that could be served by +r.timestamp_public+.
        # This does not check the file is inside the directory for performance reasons,
        # so this should not be called with untrusted input.
        def timestamp_path(file)
          mtime = File.mtime(File.join(self.class.public_root, file))
          "/#{self.class.timestamp_public_prefix}/#{sprintf("%i%06i", mtime.to_i, mtime.usec)}/#{file}"
        end
      end

      module RequestMethods
        # Serve files from the public directory if the file exists,
        # it includes the timestamp_public prefix segment followed by
        # a integer segment for the timestamp, and this is a GET request.
        def timestamp_public
          if is_get?
            on roda_class.timestamp_public_prefix, Integer do |_|
              public
            end
          end
        end
      end
    end

    register_plugin(:timestamp_public, TimestampPublic)
  end
end
