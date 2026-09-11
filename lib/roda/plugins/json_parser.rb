# frozen-string-literal: true

require 'json'

class Roda
  module RodaPlugins
    # The json_parser plugin parses request bodies in JSON format
    # if the request's content type specifies json. This is mostly
    # designed for use with JSON API sites.
    #
    # This only parses the request body as JSON if the Content-Type
    # header for the request includes "json".
    #
    # The parsed JSON body will be available in +r.POST+, just as a
    # parsed HTML form body would be. It will also be available in
    # +r.params+ (which merges +r.GET+ with +r.POST+).
    module JsonParser
      DEFAULT_ERROR_HANDLER = proc{|r| r.halt [400, {}, []]}

      # simplecov:disable
      MATCH_METHOD = RUBY_VERSION >= '2.4' ? :match? : :match
      # simplecov:enable
      private_constant :MATCH_METHOD

      # Handle options for the json_parser plugin:
      # :content_type_regexp :: A regexp used to determine if the request's
      #                         content type is JSON. For backwards compatibility,
      #                         uses the insecure /json/ if not provided. Warns
      #                         if this option is not provided. The recommended
      #                         value to use is /\Aapplication\/json\b/i or
      #                         /\Aapplication\/(?:vnd\.api\+)?json\b/i. Roda 4
      #                         will default to the latter.
      # :error_handler :: A proc to call if an exception is raised when
      #                   parsing a JSON request body.  The proc is called
      #                   with the request object, and should probably call
      #                   halt on the request or raise an exception.
      # :parser :: The parser to use for parsing incoming json.  Should be
      #            an object that responds to +call(str)+ and returns the
      #            parsed data.  The default is to call JSON.parse.
      # :include_request :: If true, the parser will be called with the request
      #                     object as the second argument, so the parser needs
      #                     to respond to +call(str, request)+.
      # :wrap :: Whether to wrap uploaded JSON data in a hash with a "_json"
      #          key.  Without this, calls to +r.params+ will fail if a non-Hash
      #          (such as an array) is uploaded in JSON format.  A value of
      #          :always will wrap all values, and a value of :unless_hash will
      #          only wrap values that are not already hashes.
      def self.configure(app, opts=OPTS)
        app.opts[:json_parser_error_handler] = opts[:error_handler] || app.opts[:json_parser_error_handler] || DEFAULT_ERROR_HANDLER
        app.opts[:json_parser_parser] = opts[:parser] || app.opts[:json_parser_parser] || app.opts[:json_parser] || JSON.method(:parse)
        app.opts[:json_parser_include_request] = opts[:include_request] if opts.has_key?(:include_request)
        app.opts[:json_parser_content_type_regexp] = opts[:content_type_regexp] || app.opts[:json_parser_content_type_regexp]

        unless app.opts[:json_parser_content_type_regexp]
          # RODA4: Switch to /\Aapplication\/(?:vnd\.api\+)?json\b/i by default
          RodaPlugins.warn(':content_type_regexp option not provided to json_parser plugin, using /json/ for backwards compatibility, which may be insecure, using /\Aapplication\/json\b/i or /\Aapplication\/(?:vnd\.api\+)?json\b/i is recommended')
          app.opts[:json_parser_content_type_regexp] = /json/
        end

        case opts[:wrap]
        when :unless_hash, :always
          app.opts[:json_parser_wrap] = opts[:wrap]
        when nil
          # Nothing
        else
          raise RodaError, "unsupported option value for json_parser plugin :wrap option: #{opts[:wrap].inspect} (should be :unless_hash or :always)"
        end
      end

      module RequestMethods
        # If the Content-Type header in the request includes "json",
        # parse the request body as JSON.  Ignore an empty request body.
        def POST
          env = @env
          if post_params = env["roda.json_params"]
            return post_params
          end

          unless (input = env["rack.input"]) && (content_type = self.content_type) && roda_class.opts[:json_parser_content_type_regexp].send(MATCH_METHOD, content_type)
            return super
          end

          str = _read_json_input(input)
          return super if str.empty?
          begin
            json_params = parse_json(str)
          rescue
            roda_class.opts[:json_parser_error_handler].call(self)
          end

          wrap = roda_class.opts[:json_parser_wrap]
          if wrap == :always || (wrap == :unless_hash && !json_params.is_a?(Hash))
            json_params = {"_json"=>json_params}
          end
          env["roda.json_params"] = json_params
          json_params
        end

        private

        def parse_json(str)
          args = [str]
          args << self if roda_class.opts[:json_parser_include_request]
          roda_class.opts[:json_parser_parser].call(*args)
        end
        
        # Rack 3 dropped requirement that input be rewindable
        if Rack.release >= '3'
          def _read_json_input(input)
            input.read
          end
        else
          def _read_json_input(input)
            input.rewind
            str = input.read
            input.rewind
            str
          end
        end
      end
    end

    register_plugin(:json_parser, JsonParser)
  end
end
