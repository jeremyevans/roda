# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The direct_call plugin makes the call class method skip the middleware stack
    # (app.call will still call the middleware).
    # This can be used as an optimization, as the Roda class itself can be used
    # as the callable, which is faster than using a lambda.
    #
    # This plugin is used automatically by Roda when freezing an app, if Roda
    # determines that doing so is safe (where there is no middleware). However,
    # it can be used manually for unfrozen apps, or in cases where middleware
    # is used.
    module DirectCall
      def self.configure(app)
        app.send(:build_rack_app)
      end

      module ClassMethods
        # Call the application without middlware.
        def call(env)
          new(env)._roda_handle_main_route
        end

        private

        # If new_api is true, use the receiver as the base rack app for better
        # performance.
        def base_rack_app_callable(new_api=true)
          if new_api
            self
          else
            super
          end
        end
      end
    end

    register_plugin(:direct_call, DirectCall)
  end
end
