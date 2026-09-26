# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The autoload_named_routes plugin builds on the named_routes plugin and allows for
    # delaying loading of a file containing a named route for an application until there
    # is a request that uses the named route. This can be useful in development
    # to improvement startup time by not loading all named routes up front.  It can also be
    # useful in testing subsets of an application by only loading the named routes being
    # tested.
    #
    # You can specify a single hash branch for autoloading:
    #
    #   plugin :autoload_named_route
    #   autoload_named_route(:route_name, '/absolute/path/to/file')
    #   autoload_named_route(:namespace, :route_name, 'relative/path/to/file')
    #
    # Note that unlike the +route+ method defined by the named_routes plugin, when providing
    # a namespace, the namespace comes before the route name and not after.
    #
    # When the autoloaded file is required, it should redefine the same
    # named route.  If it does not, requests to the named route will be ignored (as if the
    # related named route block was empty).
    #
    # When freezing an application, all named routes are automatically loaded, because
    # autoloading named routes does not work for frozen applications.
    module AutoloadNamedRoutes
      def self.load_dependencies(app)
        app.plugin :named_routes
      end

      def self.configure(app)
        app.opts[:autoload_named_route_files] ||= []
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :autoload_named_route_files)

        # Autoload the given file when there is request for the named route.
        # The given file should configure the named route specified.
        def autoload_named_route(namespace=nil, name, file)
          file = File.expand_path(file)
          autoload_named_route_files << file
          routes = namespaced_routes[namespace] ||= {}
          meth = routes[name] = define_roda_method(routes[name] || "named_routes_#{namespace}_#{name}", 1) do |r|
            loc = method(routes[name]).source_location
            require file
            # Avoid infinite loop in case method is not overridden
            if method(meth).source_location != loc
              send(meth, r)
            end
          end
          nil
        end

        # Eagerly load all autoloaded named routes when freezing the application.
        def freeze
          unless opts.frozen?
            autoload_named_route_files.each{|file| require file}
            opts[:autoload_named_route_files] = nil
            opts.delete(:autoload_named_route_files)
          end
          super
        end
      end
    end

    register_plugin(:autoload_named_routes, AutoloadNamedRoutes)
  end
end
