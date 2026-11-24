# frozen-string-literal: true

class Roda
  module RodaPlugins
    # The json plugin allows match blocks to return
    # arrays or hashes, and have those arrays or hashes be
    # serialized to JSON and used as the response body.
    # It also sets the response content type to application/json
    # if doing JSON serialization.
    # This allows you to convert code from:
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
    # to:
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
    # can set the allowed classes to serialize to JSON by adding
    # using the +classes+ argument when loading the plugin:
    #
    #   plugin :json, classes: [Array, Hash, Sequel::Model]
    #
    # By default, objects are serialized with +to_json+, but you
    # can use the +serializer+ argument to customize this. You can pass
    # any object that responds to +call(object)+.
    #
    #   plugin :json, serializer: proc{|o| o.to_json(root: true)}
    #
    # If you need the request information during serialization, such
    # as HTTP headers or query parameters, you can pass in the
    # +include_request+ argument, which will pass in the request
    # object as the second argument when calling the serializer.
    #
    #   plugin :json, include_request: true, serializer: proc{|o, request| ...}
    #
    # The default content-type is 'application/json', but you can change that
    # using the +content_type+ argument :
    #
    #   plugin :json, content_type: 'application/vnd.api.json'
    #
    # This plugin depends on the custom_block_results plugin, and therefore does
    # not support treating String, FalseClass, or NilClass values as JSON.
    module Json
      def self.load_dependencies(app, opts=OPTS)
        app.plugin :_json
        app.plugin :custom_block_results
      end

      # Set the classes to automatically convert to JSON, and the serializer to use.
      def self.configure(app, opts=(no_positional_opts = true; OPTS),
          classes: opts[:classes],
          content_type: opts[:content_type],
          include_request: opts[:include_request],
          serializer: opts[:serializer],
          **kw)
        RodaPlugins.check_keywords("the json plugin", no_positional_opts, opts, kw)

        classes ||= [Array, Hash]
        app.opts[:json_result_classes] ||= EMPTY_ARRAY
        app.opts[:json_result_classes] += classes
        classes = app.opts[:json_result_classes]
        classes.uniq!
        classes.freeze
        classes.each do |klass|
          app.custom_block_results[klass] = :handle_json_block_result
        end

        app.opts[:json_result_serializer] = serializer || app.json_result_serializer || app.json_serializer

        app.opts[:json_result_include_request] = include_request unless include_request.nil?

        app.opts[:json_result_content_type] = content_type || 'application/json'.freeze
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :json_result_serializer)
        RodaPlugins.opt_attr_reader(self, :json_result_include_request, name: :json_result_include_request?)
        RodaPlugins.opt_attr_reader(self, :json_result_content_type)

        # The classes that should be automatically converted to json
        def json_result_classes
          RodaPlugins.warn("The json_result_classes method is deprecated and will be removed in Roda 4.", uplevel: 1)
          opts[:json_result_classes]
        end
      end

      module InstanceMethods
        # Handle a result for one of the registered JSON result classes
        # by converting the result to JSON.
        def handle_json_block_result(result)
          @_response[RodaResponseHeaders::CONTENT_TYPE] ||= self.class.json_result_content_type
          @_request.send(:convert_to_json, result)
        end
      end

      module RequestMethods
        private

        # Convert the given object to JSON.  Uses to_json by default,
        # but can use a custom serializer passed to the plugin.
        def convert_to_json(result)
          serializer = roda_class.json_result_serializer

          if roda_class.json_result_include_request?
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
