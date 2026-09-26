# frozen-string-literal: true

require 'json'

#
class Roda
  module RodaPlugins
    module JSON_
      module ClassMethods
        def json_parser
          @opt_json_parser || ::JSON.method(:parse)
        end

        def json_serializer
          @opt_json_serializer || :to_json.to_proc
        end
      end
    end

    register_plugin(:_json, JSON_)
  end
end
