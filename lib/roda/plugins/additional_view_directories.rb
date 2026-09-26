# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The additional_view_directories plugin allows for specifying additional view
    # directories to look in for templates.  When rendering a template, it will
    # first try the :views directory specified in the render plugin.  If the template
    # file to be rendered does not exist in that directory, it will try each additional
    # view directory specified in this plugin, in order, using the path to the first
    # template file that exists in the file system.  If no such path is found, it
    # uses the default path specified by the render plugin.
    #
    # Example:
    #
    #   plugin :render, :views=>'dir'
    #   plugin :additional_view_directories, ['dir1', 'dir2', 'dir3']
    #
    #   route do |r|
    #     # Will check the following in order, using path for first
    #     # template file that exists:
    #     # * dir/t.erb
    #     # * dir1/t.erb
    #     # * dir2/t.erb
    #     # * dir3/t.erb
    #     render :t
    #   end
    module AdditionalViewDirectories
      # Depend on the render plugin, since this plugin only makes
      # sense when the render plugin is used.
      def self.load_dependencies(app, view_dirs)
        app.plugin :render
      end

      # Set the additional view directories to look in. Each additional view directory
      # is also added as an allowed path.
      def self.configure(app, view_dirs)
        view_dirs = app.opts[:additional_view_directories] = view_dirs.map{|f| app.expand_path(f, nil)}.freeze
        app.plugin :render, :allowed_paths=>(app.opts[:render][:allowed_paths] + view_dirs).uniq.freeze
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :additional_view_directories)
      end

      module InstanceMethods
        private

        # If the template path does not exist, try looking for the template
        # in each of the additional view directories, in order, returning
        # the first path that exists. If no additional directory includes
        # the template, return the original path.
        def template_path(opts)
          orig_path = super

          unless File.file?(orig_path)
            self.class.additional_view_directories.each do |view_dir|
              path = super(opts.merge(:views=>view_dir))
              return path if File.file?(path)
            end
          end

          orig_path
        end
      end
    end

    register_plugin(:additional_view_directories, AdditionalViewDirectories)
  end
end
