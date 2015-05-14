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
        # Attempts to parse JSON if the `Roda::RodaPlugins::Json` plugin
        # is loaded, and the payload is parsable JSON. If the payload
        # is not parsable JSON it will fall back to the raw String content.
        # If the JSON Plugin is not loaded, the raw String content will be
        # returned.
        def payload
          @_payload ||=
            if Roda::RodaPlugins.instance_variable_get(:@plugins)[:json] && defined?(JSON)
              JSON.parse(raw_payload) rescue raw_payload
            else
              raw_payload
            end
        end

        private

        # Reads the payload data to a String if it exists in `request.env`
        def raw_payload
          @_raw_payload ||= request.env['rack.input'].read
        rescue
          nil
        end
      end  
    end

    register_plugin(:payload, Payload)
  end
end
