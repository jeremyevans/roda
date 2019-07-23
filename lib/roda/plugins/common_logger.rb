# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The common_logger plugin adds common logger support to Roda
    # applications, similar to Rack::CommonLogger, with the following
    # differences:
    #
    # * Better performance
    # * Doesn't include middleware timing
    # * Doesn't proxy the body
    # * Doesn't support different capitalization of the Content-Length response header
    # * Logs to $stderr instead of env['rack.errors'] if explicit logger not passed
    #
    # Example:
    #
    #   plugin :common_logger
    #   plugin :common_logger, $stdout
    #   plugin :common_logger, Logger.new('filename')
    module CommonLogger
      def self.configure(app, logger=nil)
        raise "logger doesn't respond to write()" unless !logger.nil? && logger.respond_to?(:write)
        raise "logger doesn't respond to <<" unless !logger.nil? && logger.respond_to?(:<<)
        raise "logger doesn't respond to call()" unless !logger.nil? && logger.respond_to?(:call)

        app.opts[:common_logger] = logger || app.opts[:common_logger] || $stderr
        app.opts[:common_logger_meth] = app.opts[:common_logger].method(:write) if logger.respond_to?(:write)
        app.opts[:common_logger_meth] = app.opts[:common_logger].method(:<<) if logger.respond_to?(:<<)
        app.opts[:common_logger_meth] = app.opts[:common_logger] if logger.respond_to?(:call)
      end

      if RUBY_VERSION >= '2.1'
        # A timer object for calculating elapsed time.
        def self.start_timer
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      else
        # :nocov:
        def self.start_timer # :nodoc:
          Time.now
        end
        # :nocov:
      end

      module InstanceMethods
        private

        # Log request/response information in common log format to logger.
        def _roda_after_90__common_logger(result)
          return unless result && result[0] && result[1]

          elapsed_time = if timer = @_request_timer
            '%0.4f' % (CommonLogger.start_timer - timer)
          else 
            '-'
          end

          env = @_request.env

          opts[:common_logger_meth].call("#{env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-"} - #{env["REMOTE_USER"] || "-"} [#{Time.now.strftime("%d/%b/%Y:%H:%M:%S %z")}] \"#{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}#{"?#{env["QUERY_STRING"]}" if ((qs = env["QUERY_STRING"]) && !qs.empty?)} #{env["HTTP_VERSION"]}\" #{result[0]} #{((length = result[1]['Content-Length']) && (length unless length == '0')) || '-'} #{elapsed_time}\n")
        end

        # Create timer instance used for timing
        def _roda_before_05__common_logger
          @_request_timer = CommonLogger.start_timer
        end
      end
    end

    register_plugin(:common_logger, CommonLogger)
  end
end
