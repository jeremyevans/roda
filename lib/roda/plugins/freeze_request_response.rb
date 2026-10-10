# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The freeze_request_response plugin freezes the RodaRequest and
    # RodaResponse classes when freezing the Roda class. This will
    # become the default behavior in Roda 4.
    module FreezeRequestResponse
      module ClassMethods
        # Freeze the RodaRequest and RodaResponse classes when freezing the Roda class.
        def freeze
          super
          # RODA4: make this behavior the default
          self::RodaRequest.freeze
          self::RodaResponse.freeze
          self
        end
      end
    end

    register_plugin(:freeze_request_response, FreezeRequestResponse)
  end
end
