# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The skip_common_logger plugin allows for skipping common_logger logging
    # of some requests. You pass a block when loading the plugin, and the
    # block will be called before logging each request.  The block should return
    # whether the request should be logged.
    #
    # Example:
    #
    #   # Only log server errors
    #   plugin :filter_common_logger do |result|
    #     result[0] >= 500
    #   end
    #
    #   # Don't log requests to certain paths
    #   plugin :filter_common_logger do |_|
    #     # Block is called in the same context as the route block
    #     !request.path.start_with?('/admin/')
    #   end
    module FilterCommonLogger
      def self.load_dependencies(app, &_)
        app.plugin :common_logger
      end

      def self.configure(app, &block)
        app.class_exec do
          define_method(:_common_log_request?, &block)
          private :_common_log_request?
          alias _common_log_request? _common_log_request?
        end
      end

      module InstanceMethods
        private

        # Do common logging only if configured to do so.
        def _roda_after_90__common_logger(result)
          super if result && _common_log_request?(result)
        end
      end
    end

    register_plugin(:filter_common_logger, FilterCommonLogger)
  end
end
