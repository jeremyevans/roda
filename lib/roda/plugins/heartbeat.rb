# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The heartbeat handles heartbeat/status requests.  If a request for
    # the heartbeat path comes in, a 200 response with a
    # text/plain Content-Type and a body of "OK" will be returned.
    # The default heartbeat path is "/heartbeat", so to use that:
    #
    #   plugin :heartbeat
    #
    # You can also specify a custom heartbeat path:
    #
    #   plugin :heartbeat, path: '/status'
    module Heartbeat
      # Set the heartbeat path to the given path.
      def self.configure(app, opts=OPTS)
        app.opts[:heartbeat_path] = (opts[:path] || app.heartbeat_path || "/heartbeat").dup.freeze
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :heartbeat_path)
      end

      module InstanceMethods
        private

        # If the request is for a heartbeat path, return the heartbeat response.
        def _roda_before_20__heartbeat
          if env['PATH_INFO'] == self.class.heartbeat_path
            response = @_response
            response.status = 200
            response[RodaResponseHeaders::CONTENT_TYPE] = 'text/plain'
            response.write 'OK'
            throw :halt, response.finish
          end
        end
      end
    end

    register_plugin(:heartbeat, Heartbeat)
  end
end

