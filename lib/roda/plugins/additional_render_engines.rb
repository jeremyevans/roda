# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The additional_render_engines plugin allows for specifying additional render
    # engines to consider for templates.  When rendering a template, it will
    # first try the default template engine specified in the render plugin.  If the
    # template file to be rendered does not exist, it will try each additional render
    # engine specified in this plugin, in order, using the path to the first
    # template file that exists in the file system.  If no such path is found, it
    # uses the default path specified by the render plugin.
    #
    # Example:
    #
    #   plugin :render # default engine is 'erb'
    #   plugin :additional_render_engines, ['haml', 'str']
    #
    #   route do |r|
    #     # Will check the following in order, using path for first
    #     # template file that exists:
    #     # * views/t.erb
    #     # * views/t.haml
    #     # * views/t.str
    #     render :t
    #   end
    module AdditionalRenderEngines
      def self.load_dependencies(app, render_engines)
        app.plugin :render
      end

      # Set the additional render engines to consider.
      def self.configure(app, render_engines)
        app.opts[:additional_render_engines] = render_engines.dup.freeze
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :additional_render_engines)
      end

      module InstanceMethods
        private

        # If the template path does not exist, try looking for the template
        # using each of the render engines, in order, returning
        # the first path that exists. If no template path exists for the
        # default any or any additional engines, return the original path.
        def template_path(opts)
          orig_path = super

          unless File.file?(orig_path)
            self.class.additional_render_engines.each do |engine|
              path = super(opts.merge(:engine=>engine))
              return path if File.file?(path)
            end
          end

          orig_path
        end
      end
    end

    register_plugin(:additional_render_engines, AdditionalRenderEngines)
  end
end
