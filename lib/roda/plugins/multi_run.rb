# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The multi_run plugin provides the ability to easily dispatch to other
    # rack applications based on the request path prefix.
    # First, load the plugin:
    #
    #   class App < Roda
    #     plugin :multi_run
    #   end
    #
    # Then, other rack applications can register with the multi_run plugin:
    #
    #   App.run "ra", PlainRackApp
    #   App.run "ro", OtherRodaApp
    #   App.run "si", SinatraApp
    #
    # Inside your route block, you can call +r.multi_run+ to dispatch to all
    # three rack applications based on the prefix:
    #
    #   App.route do |r|
    #     r.multi_run
    #   end
    #
    # This will dispatch routes starting with +/ra+ to +PlainRackApp+, routes
    # starting with +/ro+ to +OtherRodaApp+, and routes starting with +/si+ to
    # SinatraApp.
    #
    # You can pass a block to +r.multi_run+ that will be called with the prefix,
    # before dispatching to the rack app:
    #
    #   App.route do |r|
    #     r.multi_run do |prefix|
    #       # do something based on prefix before the request is passed further
    #     end
    #   end
    #
    # This is useful for modifying the environment before passing it to the rack app.
    #
    # You can also call +Roda.run+ with a block:
    #
    #   App.run("ra"){PlainRackApp}
    #   App.run("ro"){OtherRodaApp}
    #   App.run("si"){SinatraApp}
    #
    # When called with a block, Roda will call the block to get the app to dispatch to
    # every time the block is called.  The expected usage is with autoloaded classes,
    # so that the related classes are not loaded until there is a request for the
    # related route.  This can sigficantly speedup startup or testing a subset of the
    # application.  When freezing an application, the blocks are called once to get the
    # app to dispatch to, and that is cached, to ensure the any autoloads are completed
    # before the application is frozen.
    #
    # The multi_run plugin is similar to the hash_branches and multi_route plugins, with
    # the difference being the hash_branches and multi_route plugins keep all routing
    # subtrees in the same Roda app/class, while multi_run dispatches to other rack apps.
    # If you want to isolate your routing subtrees, multi_run is a better approach, but
    # it does not let you set instance variables in the main Roda app and have those
    # instance variables usable in the routing subtrees.
    #
    # To handle development environments that reload code, you can call the
    # +run+ class method without an app to remove dispatching for the prefix.
    module MultiRun
      # Initialize the storage for the dispatched applications
      def self.configure(app)
        app.opts[:multi_run_apps] ||= {}
        app.opts[:multi_run_app_blocks] ||= {}
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :multi_run_apps)
        RodaPlugins.opt_attr_reader(self, :multi_run_app_blocks)

        # Convert app blocks into apps by calling them, in order to force autoloads
        # and to speed up subsequent calls.
        # Freeze the multi_run apps so that there can be no thread safety issues at runtime.
        def freeze
          app_blocks = multi_run_app_blocks
          apps = multi_run_apps
          app_blocks.each do |prefix, block|
            apps[prefix] = block.call
          end
          app_blocks.clear.freeze
          apps.freeze
          self::RodaRequest.refresh_multi_run_regexp!
          super
        end

        # Add a rack application to dispatch to for the given prefix when
        # r.multi_run is called. If a block is given, it is called every time
        # there is a request for the route to get the app to call. If neither
        # a block or an app is provided, any stored route for the prefix is
        # removed.  It is an error to provide both an app and block in the same call.
        def run(prefix, app=nil, &block)
          prefix = prefix.to_s
          if app 
            raise Roda::RodaError, "cannot provide both app and block to Roda.run" if block
            multi_run_apps[prefix] = app
            multi_run_app_blocks.delete(prefix)
          elsif block
            multi_run_apps.delete(prefix)
            multi_run_app_blocks[prefix] = block
          else
            multi_run_apps.delete(prefix)
            multi_run_app_blocks.delete(prefix)
          end
          self::RodaRequest.refresh_multi_run_regexp!
        end
      end

      module RequestClassMethods
        # Refresh the multi_run_regexp, using the stored route prefixes,
        # preferring longer routes before shorter routes.
        def refresh_multi_run_regexp!
          @multi_run_regexp = /(#{Regexp.union((roda_class.multi_run_apps.keys + roda_class.multi_run_app_blocks.keys).sort.reverse)})/
        end

        # Refresh the multi_run_regexp if it hasn't been loaded yet.
        def multi_run_regexp
          @multi_run_regexp || refresh_multi_run_regexp!
        end
      end

      module RequestMethods
        # If one of the stored route prefixes match the current request,
        # dispatch the request to the appropriate rack application.
        def multi_run
          on self.class.multi_run_regexp do |prefix|
            yield prefix if defined?(yield)
            run(roda_class.multi_run_apps[prefix] || roda_class.multi_run_app_blocks[prefix].call)
          end
        end
      end
    end

    register_plugin(:multi_run, MultiRun)
  end
end
