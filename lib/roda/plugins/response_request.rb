# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The response_request plugin gives the response access to the
    # related request instance via the #request method.
    #
    # Example:
    #
    #   plugin :response_request
    module ResponseRequest
      # This isn't set because it breaks usage with the error_handler/class_level_routing
      # plugins and the shape_friendly plugin, due to those calling RodaResponse#initialize,
      # which would reset @request to nil. It isn't strictly necessary to set this for
      # shape friendliness, as the Roda#initialize sets it directly after creating the
      # RodaRequest, so in normal use, the instance variable will already be set.
      # RESPONSE_INSTANCE_VARIABLES = [:@request].freeze

      module InstanceMethods
        # Set the response's request to the current request.
        def initialize(env)
          super
          @_response.request = @_request
        end
      end

      module ResponseMethods
        # The request related to this response.
        attr_accessor :request
      end
    end

    register_plugin(:response_request, ResponseRequest)
  end
end
