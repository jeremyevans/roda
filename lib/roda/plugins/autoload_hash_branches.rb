# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The autoload_hash_branches plugin builds on the hash_branches plugin and allows for
    # delaying loading of a file containing a hash branch for an application until there
    # is a request that uses the hash branch. This can be useful in development
    # to improvement startup time by not loading all branches up front.  It can also be
    # useful in testing subsets of an application by only loading the hash branches being
    # tested.
    #
    # You can specify a single hash branch for autoloading:
    #
    #   plugin :autoload_hash_branches
    #   autoload_hash_branch('branch_name', '/absolute/path/to/file')
    #   autoload_hash_branch('namespace', 'branch_name', 'relative/path/to/file')
    #
    # You can also set the plugin to autoload load all hash branch files in a given directory.
    # This will look at each .rb file in the directory, and add an autoload for it, using the
    # filename without the .rb as the branch name:
    #
    #   autoload_hash_branch_dir('/path/to/dir')
    #   autoload_hash_branch_dir('namespace', '/path/to/dir')
    #
    # In both cases, when the autoloaded file is required, it should redefine the same
    # hash branch.  If it does not, requests to the hash branch will result in a 404 error.
    #
    # When freezing an application, all hash branches are automatically loaded, because
    # autoloading hash branches does not work for frozen applications.
    module AutoloadHashBranches
      def self.load_dependencies(app)
        app.plugin :hash_branches
      end

      def self.configure(app)
        app.opts[:autoload_hash_branch_files] ||= []
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :autoload_hash_branch_files)

        # Autoload the given file when there is request for the hash branch.
        # The given file should configure the hash branch specified.
        def autoload_hash_branch(namespace='', segment, file)
          segment = "/#{segment}"
          file = File.expand_path(file)
          autoload_hash_branch_files << file
          routes = hash_branches[namespace] ||= {}
          meth = routes[segment] = define_roda_method(routes[segment] || "hash_branch_#{namespace}_#{segment}", 1) do |r|
            loc = method(routes[segment]).source_location
            require file
            # Avoid infinite loop in case method is not overridden
            if method(meth).source_location != loc
              send(meth, r)
            end
          end
          nil
        end

        # For each .rb file in the given directory, add an autoloaded hash branch
        # based on the file name.
        def autoload_hash_branch_dir(namespace='', dir)
          Dir.new(dir).entries.each do |file|
            if file =~ /\.rb\z/i
              autoload_hash_branch(namespace, file.sub(/\.rb\z/i, ''), File.join(dir, file))
            end
          end
        end

        # Eagerly load all hash branches when freezing the application.
        def freeze
          unless opts.frozen?
            autoload_hash_branch_files.each{|file| require file}
            opts[:autoload_hash_branch_files] = nil
            opts.delete(:autoload_hash_branch_files)
          end
          super
        end
      end
    end

    register_plugin(:autoload_hash_branches, AutoloadHashBranches)
  end
end
