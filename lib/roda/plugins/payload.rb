class Roda
  module RodaPlugins
    # The payload plugin adds a +payload+ instance
    # method which returns a copy of the payload data (as a String)
    # if it is available. Useful when such data is being sent
    # via a GET request or non-POST request.
    # Example:
    #
    #   plugin :indifferent_params
    #
    #   route do |r|
    #     payload
    #   end
    #
    # The payload String is initialized lazily, so you only pay
    # the penalty of copying the request params if you call
    # the +payload+ method.
    module Payload
      module InstanceMethods
        # A copy of the payload
        def payload
          @_payload ||= request.env['rack.input'].read
        rescue
          nil
        end
      end  
    end

    register_plugin(:payload, Payload)
  end
end
