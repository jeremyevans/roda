# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The response_content_type extension adds response.content_type
    # and response.content_type= methods for getting and setting the
    # response content-type.
    #
    # When setting the content-type, you can pass either a string, which
    # is used directly:
    #
    #   response.content_type = "text/html"
    # 
    # Or, if you have registered mime types when loading the plugin:
    #
    #   plugin :response_content_type, mime_types: {
    #     plain: "text/plain",
    #     html: "text/html",
    #     pdf: "application/pdf"
    #   }
    #
    # You can use a symbol:
    #
    #   response.content_type = :html
    #
    # If you would like to load all mime types supported by rack/mime,
    # you can use the <tt>mime_types: :from_rack_mime</tt> option:
    #
    #   plugin :response_content_type, mime_types: :from_rack_mime
    #
    # Note that you are unlikely to be using all of these mime types,
    # so doing this will likely result in unnecessary memory usage. It
    # is recommended to use a hash with only the mime types your
    # application actually uses.
    #
    # To prevent silent failures, if you attempt to set the response
    # type with a symbol, and the symbol is not recognized, a KeyError
    # is raised.
    module ResponseContentType
      def self.configure(app, opts=OPTS)
        if mime_types = opts[:mime_types]
          mime_types = if mime_types == :from_rack_mime
            require "rack/mime"
            h = {}
            Rack::Mime::MIME_TYPES.each do |k, v|
              h[k.slice(1,100).to_sym] = v
            end
            h
          else
            mime_types.dup
          end
          app.opts[:response_content_types] = mime_types.freeze
        else
          app.opts[:response_content_types] ||= {}
        end
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :response_content_types)
      end

      module ResponseMethods
        # Return the content-type of the response. Will be nil if it has
        # not yet been explicitly set.
        def content_type
          @headers[RodaResponseHeaders::CONTENT_TYPE]
        end

        # Set the content-type of the response. If given a string,
        # it is used directly. If given a symbol, looks up the mime
        # type with the given file extension. If the symbol is not
        # a recognized mime type, raises KeyError.
        def content_type=(mime_type)
          mime_type = roda_class.response_content_types.fetch(mime_type) if mime_type.is_a?(Symbol)
          @headers[RodaResponseHeaders::CONTENT_TYPE] = mime_type
        end
      end
    end

    register_plugin(:response_content_type, ResponseContentType)
  end
end
