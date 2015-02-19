require 'json'

class Roda
  module RodaPlugins
    # The json plugin allows match blocks to return
    # arrays or hashes, and have those arrays or hashes be
    # converted to json which is used as the response body.
    # It also sets the response content type to application/json.
    # So you can take code like:
    #
    #   r.root do
    #     response['Content-Type'] = 'application/json'
    #     [1, 2, 3].to_json
    #   end
    #   r.is "foo" do
    #     response['Content-Type'] = 'application/json'
    #     {'a'=>'b'}.to_json
    #   end
    #
    # and DRY it up:
    #
    #   plugin :json
    #   r.root do
    #     [1, 2, 3]
    #   end
    #   r.is "foo" do
    #     {'a'=>'b'}
    #   end
    #
    # By default, only arrays and hashes are handled, but you
    # can specifically set the allowed classes to json by adding
    # using the :classes option when loading the plugin:
    #
    #   plugin :json, :classes=>[Array, Hash, Sequel::Model]
    module Json
      OPTS = {}.freeze

      # Set the classes to automatically convert to JSON
      def self.configure(app, opts=OPTS)
        classes = opts[:classes] || [Array, Hash]
        app.opts[:json_result_classes] ||= []
        app.opts[:json_result_classes] += classes
        app.opts[:json_result_classes].uniq!
        app.opts[:json_result_classes].freeze
      end

      module ClassMethods
        # The classes that should be automatically converted to json
        def json_result_classes
          opts[:json_result_classes]
        end
      end

      module RequestMethods
        CONTENT_TYPE     = 'Content-Type'.freeze
        APPLICATION_JSON = 'application/json'.freeze

        private

        # If the result is an instance of one of the json_result_classes,
        # convert the result to json and return it as the body, using the
        # application/json content-type.
        def block_result_body(result)
          case result
          when *roda_class.json_result_classes
            response[CONTENT_TYPE] = APPLICATION_JSON
            convert_to_json(result)
          else
            super
          end
        end

        # Convert the given object to JSON.  Uses to_json by default,
        # but can be overridden to use a different implementation.
        def convert_to_json(obj)
          obj.to_json
        end
      end
    end

    register_plugin(:json, Json)
  end
end
