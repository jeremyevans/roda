# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The error_handler plugin adds an error handler to the routing,
    # so that if routing the request raises an error, a nice error
    # message page can be returned to the user.
    # 
    # You can provide the error handler as a block to the plugin:
    #
    #   plugin :error_handler do |e|
    #     "Oh No!"
    #   end
    #
    # Or later via the +error+ class method:
    #
    #   plugin :error_handler
    #
    #   error do |e|
    #     "Oh No!"
    #   end
    #
    # In both cases, the exception instance is passed into the block,
    # and the block can return the request body via a string.
    #
    # If an exception is raised, a new response will be used, with the
    # default status set to 500, before executing the error handler.
    # The error handler can change the response status if necessary,
    # as well set headers and/or write to the body, just like a regular
    # request.  After the error handler returns a response, normal after
    # processing of that response occurs, except that an exception during
    # after processing is logged to <tt>env['rack.errors']</tt> but
    # otherwise ignored. This avoids recursive calls into the
    # error_handler.  Note that if the error_handler itself raises
    # an exception, the exception will be raised without normal after
    # processing.  This can cause some after processing to run twice
    # (once before the error_handler is called and once after) if
    # later after processing raises an exception.
    #
    # By default, this plugin handles StandardError and ScriptError.
    # To override the exception classes it will handle, pass a :classes
    # option to the plugin:
    #
    #   plugin :error_handler, classes: [StandardError, ScriptError, NoMemoryError]
    module ErrorHandler
      DEFAULT_ERROR_HANDLER_CLASSES = [StandardError, ScriptError].freeze

      # If a block is given, automatically call the +error+ method on
      # the Roda class with it.
      def self.configure(app, opts={}, &block)
        app.opts[:error_handler_classes] = (opts[:classes] || app.error_handler_classes || DEFAULT_ERROR_HANDLER_CLASSES).dup.freeze

        if block
          app.error(&block)
        end
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :error_handler_classes)

        # Install the given block as the error handler, so that if routing
        # the request raises an exception, the block will be called with
        # the exception in the scope of the Roda instance.
        def error(&block)
          define_method(:handle_error, &block)
          alias_method(:handle_error, :handle_error)
          private :handle_error
        end
      end

      module InstanceMethods
        # If an error occurs, set the response status to 500 and call
        # the error handler. Old Dispatch API.
        def call
          # RODA4: Remove
          begin
            res = super
          ensure
            _roda_after(res)
          end
        rescue *self.class.error_handler_classes => e
          _handle_error(e)
        end

        # If an error occurs, set the response status to 500 and call
        # the error handler. 
        def _roda_handle_main_route
          begin
            res = super
          ensure
            _roda_after(res)
          end
        rescue *self.class.error_handler_classes => e
          _handle_error(e)
        end

        private

        # Default empty implementation of _roda_after, usually
        # overridden by Roda.def_roda_before.
        def _roda_after(res)
        end

        # Handle the given exception using handle_error, using a default status
        # of 500.  Run after hooks on the rack response, but if any error occurs
        # when doing so, log the error using rack.errors and return the response.
        def _handle_error(e)
          res = @_response
          res.send(:initialize)
          res.status = 500
          res = _roda_handle_route{handle_error(e)}
          begin
            _roda_after(res)
          rescue => e2
            if errors = env['rack.errors']
              errors.puts "Error in after hook processing of error handler: #{e2.class}: #{e2.message}"
              e2.backtrace.each{|line| errors.puts(line)}
            end
          end
          res
        end

        # By default, have the error handler reraise the error, so using
        # the plugin without installing an error handler doesn't change
        # behavior.
        def handle_error(e)
          raise e
        end
      end
    end

    register_plugin(:error_handler, ErrorHandler)
  end
end
