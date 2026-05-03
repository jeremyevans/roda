# frozen-string-literal: true

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
    #   plugin :json, classes: [Array, Hash, Sequel::Model]
    #
    # By default objects are serialized with +to_json+, but you
    # can pass in a custom serializer, which can be any object
    # that responds to +call(object)+.
    #
    #   plugin :json, serializer: proc{|o| o.to_json(root: true)}
    #
    # If you need the request information during serialization, such
    # as HTTP headers or query parameters, you can pass in the
    # +:include_request+ option, which will pass in the request
    # object as the second argument when calling the serializer.
    #
    #   plugin :json, include_request: true, serializer: proc{|o, request| ...}
    #
    # The default content-type is 'application/json', but you can change that
    # using the +:content_type+ option:
    #
    #   plugin :json, content_type: 'application/xml'
    #
    # This plugin depends on the custom_block_results plugin, and therefore does
    # not support treating String, FalseClass, or NilClass values as JSON.
    module Json
      def self.load_dependencies(app, opts=OPTS)
        app.plugin :custom_block_results
      end

      # Set the classes to automatically convert to JSON, and the serializer to use.
      def self.configure(app, opts=OPTS)
        classes = opts[:classes] || [Array, Hash]
        app.opts[:json_result_classes] ||= []
        app.opts[:json_result_classes] += classes
        classes = app.opts[:json_result_classes]
        classes.uniq!
        classes.freeze
        classes.each do |klass|
          app.opts[:custom_block_results][klass] = :handle_json_block_result
        end

        app.opts[:json_result_serializer] = opts[:serializer] || app.opts[:json_result_serializer] || app.opts[:json_serializer] || :to_json.to_proc

        app.opts[:json_result_include_request] = opts[:include_request] if opts.has_key?(:include_request)

        app.opts[:json_result_content_type] = opts[:content_type] || 'application/json'.freeze
      end

      module ClassMethods
        # The classes that should be automatically converted to json
        def json_result_classes
          # RODA4: remove, only used by previous implementation.
          opts[:json_result_classes]
        end
      end

      module InstanceMethods
        # Handle a result for one of the registered JSON result classes
        # by converting the result to JSON.
        def handle_json_block_result(result)
          @_response[RodaResponseHeaders::CONTENT_TYPE] ||= opts[:json_result_content_type]
          @_request.send(:convert_to_json, result)
        end
      end

      module RequestMethods
        private

        # Convert the given object to JSON.  Uses to_json by default,
        # but can use a custom serializer passed to the plugin.
        def convert_to_json(result)
          opts = roda_class.opts
          serializer = opts[:json_result_serializer]

          if opts[:json_result_include_request]
            serializer.call(result, self)
          else
            serializer.call(result)
          end
        end
      end
    end

    register_plugin(:json, Json)
  end
end
