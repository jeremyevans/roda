# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The invalid_request_body plugin allows for custom handling of invalid request
    # bodies.  Roda uses Rack for parsing request bodies, so by default, any
    # invalid request bodies would result in Rack raising an exception, and the
    # exception could change for different reasons the request body is invalid.
    # This plugin overrides RodaRequest#POST (which parses parameters from request
    # bodies), and if parsing raises an exception, it allows for custom behavior.
    # 
    # If you want to treat an invalid request body as the submission of no parameters,
    # you can use the :empty_hash argument when loading the plugin:
    #
    #   plugin :invalid_request_body, :empty_hash
    #
    # If you want to return a empty 400 (Bad Request) response if an invalid request
    # body is submitted, you can use the :empty_400 argument when loading the plugin:
    #
    #   plugin :invalid_request_body, :empty_400
    #
    # If you want to raise a Roda::RodaPlugins::InvalidRequestBody::Error exception
    # if an invalid request body is submitted (which makes it easier to handle these
    # exceptions when using the error_handler plugin), you can use the :raise argument
    # when loading the plugin:
    #
    #   plugin :invalid_request_body, :raise
    #
    # For custom behavior, you can pass a block when loading the plugin.  The block
    # is called with the exception Rack raised when parsing the body. The block will
    # be used to define a method in the application's RodaRequest class.  It can either
    # return a hash of parameters, or you can raise a different exception, or you
    # can halt processing and return a response:
    #
    #   plugin :invalid_request_body do |exception|
    #     # To treat the exception raised as a submitted parameter
    #     {body_error: exception}
    #   end
    module InvalidRequestBody
      # Exception class raised for invalid request bodies.
      Error = Class.new(RodaError)

      # Set the action to use (:empty_400, :empty_hash, :raise) for invalid request bodies,
      # or use a block for custom behavior.
      def self.configure(app, action=nil, &block)
        if action
          if block
            raise RodaError, "cannot provide both block and action when loading invalid_request_body plugin"
          end

          method = :"handle_invalid_request_body_#{action}"
          unless RequestMethods.private_method_defined?(method)
            raise RodaError, "invalid invalid_request_body action provided: #{action}"
          end

          app::RodaRequest.send(:alias_method, :handle_invalid_request_body, method)
        elsif block
          app::RodaRequest.class_eval do
            define_method(:handle_invalid_request_body, &block)
            alias handle_invalid_request_body handle_invalid_request_body
          end
        else
          raise RodaError, "must provide block or action when loading invalid_request_body plugin"
        end

        app::RodaRequest.send(:private, :handle_invalid_request_body)
      end

      module RequestMethods
        # Handle invalid request bodies as configured if the default behavior
        # raises an exception.
        def POST
          super
        rescue RodaError
          raise
        rescue => e 
          handle_invalid_request_body(e)
        end

        private

        # Return an empty 400 HTTP response for invalid request bodies.
        def handle_invalid_request_body_empty_400(e)
          response.status = 400
          headers = response.headers
          headers.clear
          headers[RodaResponseHeaders::CONTENT_TYPE] = 'text/html'
          headers[RodaResponseHeaders::CONTENT_LENGTH] ='0'
          throw :halt, response.finish_with_body([])
        end

        # Treat invalid request bodies by using an empty hash as the
        # POST params.
        def handle_invalid_request_body_empty_hash(e)
          {}
        end

        # Raise a specific error for all invalid request bodies,
        # to allow for easy rescuing using the error_handler plugin.
        def handle_invalid_request_body_raise(e)
          raise Error, e.message
        end
      end
    end

    register_plugin(:invalid_request_body, InvalidRequestBody)
  end
end
