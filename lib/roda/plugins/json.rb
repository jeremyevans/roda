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
    #
    # The json plugin also allows request bodies to be parsed and merged
    # into the hash available via `params`. This `params` method works
    # in conjunction with indifferent_params plugin if it is included.
    #
    # To have Roda parse JSON requests:
    #
    #   plugin :json, :request_body => true
    #
    # If the request body is unparseable, `response.status` is set to 400.
    # If the body is an Array, it is parsed and set at `params[:body]`.
    #
    module Json
      OPTS = {}.freeze
      APPLICATION_JSON = 'application/json'.freeze

      # Set the classes to automatically convert to JSON
      def self.configure(app, opts=OPTS)
        classes = opts[:classes] || [Array, Hash]
        app.opts[:json_result_classes] ||= []
        app.opts[:json_result_classes] += classes
        app.opts[:json_result_classes].uniq!
        app.opts[:json_result_classes].freeze

        app.opts[:json_request_body] = !!opts[:request_body]
        app.opts[:json_request_body].freeze
      end

      module ClassMethods
        # The classes that should be automatically converted to json
        def json_result_classes
          opts[:json_result_classes]
        end

        def json_request_body?
          opts[:json_request_body]
        end
      end

      module RequestMethods
        CONTENT_TYPE = 'Content-Type'.freeze

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

      module InstanceMethods

        # Convert the given JSON to object.  Uses `JSON.parse` by default,
        # but can be overridden to use a different implementation.
        def convert_body_from_json
          JSON.parse(request.body.read)
        rescue JSON::ParserError
          response.status = 400
        ensure
          request.body.rewind
        end

        # Lazily initialize a `@_params` instance variable, similar to
        # indifferent_params plugin. Merge objects into params, set Arrays
        # at params[:body]. Run through `indifferent_params` if available.
        def params
          unless @_params
            @_params = request.params
            if self.class.json_request_body? and json_request?
              case b = convert_body_from_json
              when Hash;  @_params.merge! b
              when Array; @_params[:body] = b
              end
            end
            @_params = indifferent_params(@_params) rescue @_params
          end
          @_params
        end

        private

        # Rack-style header keys
        CONTENT_TYPE_KEY = 'CONTENT_TYPE'.freeze

        # Do request headers indicate JSON data?
        def json_request?
          request.env.has_key?(CONTENT_TYPE_KEY) and
            request.env[CONTENT_TYPE_KEY][0,16] == APPLICATION_JSON
        end

      end
    end

    register_plugin(:json, Json)
  end
end
