# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The strip_path_prefix plugin makes Roda strip a given prefix off internal absolute paths,
    # turning them to relative paths.  Roda by default stores internal paths as absolute paths.
    # The main reason to use this plugin is when the internal absolute path could change at
    # runtime, either due to a symlink change or chroot call, or you really want to use
    # relative paths instead of absolute paths.
    # 
    # Examples:
    #
    #   plugin :strip_path_prefix # Defaults to Dir.pwd
    #   plugin :strip_path_prefix, File.dirname(Dir.pwd)
    module StripPathPrefix
      # Set the regexp to use when stripping prefixes from internal paths.
      def self.configure(app, prefix=Dir.pwd)
        prefix += '/' unless prefix.end_with?("/")
        app.opts[:strip_path_prefix] = /\A#{Regexp.escape(prefix)}/
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :strip_path_prefix, name: :strip_path_prefix_regexp)

        # Strip the path prefix from the gien path if it starts with the prefix.
        def expand_path(path, root=app_root)
          super.sub(strip_path_prefix_regexp, '')
        end
      end
    end

    register_plugin(:strip_path_prefix, StripPathPrefix)
  end
end
