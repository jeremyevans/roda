# frozen-string-literal: true

class Roda
  module RodaPlugins
    # The conditional_sessions plugin loads the sessions plugin.  However,
    # it only allows sessions if the block passed to the plugin returns
    # truthy.  The block is evaluated in request context. This is designed for
    # use in applications that want to use sessions for some requests,
    # and want to be sure that sessions are not used for other requests.
    # For example, if you want to make sure that sessions are not used for
    # requests with paths starting with /static, you could do:
    #
    #   plugin :conditional_sessions, secret: ENV["SECRET"] do
    #     !path_info.start_with?('/static')
    #   end
    #
    # The the request session, session_created_at, and session_updated_at methods
    # raise a RodaError exception when sessions are not allowed.  The request
    # persist_session and route scope clear_session methods do nothing when
    # sessions are not allowed.
    module ConditionalSessions
      # Pass all options to the sessions block, and use the block to define
      # a request method for whether sessions are allowed.
      def self.load_dependencies(app, opts=OPTS, &block)
        app.plugin :sessions, opts
        app::RodaRequest.class_exec do
          define_method(:use_sessions?, &block)
          alias use_sessions? use_sessions?
        end
      end

      module InstanceMethods
        # Do nothing if not using sessions.
        def clear_session
          super if @_request.use_sessions?
        end
      end

      module RequestMethods
        # Raise RodaError if not using sessions.
        def session
          raise RodaError, "session called on request not using sessions" unless use_sessions?
          super
        end

        # Raise RodaError if not using sessions.
        def session_created_at
          raise RodaError, "session_created_at called on request not using sessions" unless use_sessions?
          super
        end

        # Raise RodaError if not using sessions.
        def session_updated_at
          raise RodaError, "session_updated_at called on request not using sessions" unless use_sessions?
          super
        end

        # Do nothing if not using sessions.
        def persist_session(headers, session)
          super if use_sessions?
        end
      end
    end

    register_plugin(:conditional_sessions, ConditionalSessions)
  end
end
