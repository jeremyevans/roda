# frozen-string-literal: true

begin
  require 'rack/headers'
rescue LoadError
end

class Roda
  # Contains constants for response headers.  This approach is used so that all
  # headers used internally by Roda can be lower case on Rack 3, so that it is
  # possible to use a plain hash of response headers instead of using Rack::Headers.
  module RodaResponseHeaders
    # RODA4: switch all constant access to downcased strings
    downcase = defined?(Rack::Headers) && Rack::Headers.is_a?(Class)

    %w'Allow Cache-Control Content-Disposition Content-Encoding Content-Length
       Content-Security-Policy Content-Security-Policy-Report-Only Content-Type
       ETag Expires Last-Modified Link Location Set-Cookie Transfer-Encoding Vary
       Permissions-Policy Permissions-Policy-Report-Only Strict-Transport-Security'.
      each do |value|
        value = value.downcase if downcase
        const_set(value.tr('-', '_').upcase!.to_sym, value.freeze)
      end
  end

  # Base class used for Roda responses.  The instance methods for this
  # class are added by Roda::RodaPlugins::Base::ResponseMethods, the class
  # methods are added by Roda::RodaPlugins::Base::ResponseClassMethods.
  class RodaResponse
    @roda_class = ::Roda
  end

  module RodaPlugins
    module Base
      # Class methods for RodaResponse
      module ResponseClassMethods
        # Reference to the Roda class related to this response class.
        attr_accessor :roda_class

        # Since RodaResponse is anonymously subclassed when Roda is subclassed,
        # and then assigned to a constant of the Roda subclass, make inspect
        # reflect the likely name for the class.
        def inspect
          "#{roda_class.inspect}::RodaResponse"
        end
      end

      # Instance methods for RodaResponse
      module ResponseMethods
        # The body for the current response.
        attr_reader :body

        # The hash of response headers for the current response.
        attr_reader :headers

        # The status code to use for the response.  If none is given, will use 200
        # code for non-empty responses and a 404 code for empty responses.
        attr_accessor :status

        # Set the default headers when creating a response.
        def initialize
          @headers = _initialize_headers
          @body    = []
          @length  = 0
        end

        # Return the response header with the given key. Example:
        #
        #   response['content-type'] # => 'text/html'
        def [](key)
          @headers[key]
        end

        # Set the response header with the given key to the given value.
        #
        #   response['content-type'] = 'application/json'
        def []=(key, value)
          @headers[key] = value
        end

        # The default headers to use for responses.
        def default_headers
          DEFAULT_HEADERS
        end

        # Whether the response body has been written to yet.  Note
        # that writing an empty string to the response body marks
        # the response as not empty. Example:
        #
        #   response.empty? # => true
        #   response.write('a')
        #   response.empty? # => false
        def empty?
          @body.empty?
        end

        # Return the rack response array of status, headers, and body
        # for the current response.  If the status has not been set,
        # uses the return value of default_status if the body has
        # been written to, otherwise uses a 404 status.
        # Adds the content-length header to the size of the response body.
        #
        # Example:
        #
        #   response.finish
        #   #  => [200,
        #   #      {'content-type'=>'text/html', 'content-length'=>'0'},
        #   #      []]
        def finish
          b = @body
          set_default_headers
          h = @headers

          if b.empty?
            s = @status || 404
            if (s == 304 || s == 204 || (s >= 100 && s <= 199))
              h.delete(RodaResponseHeaders::CONTENT_TYPE)
            elsif s == 205
              empty_205_headers(h)
            else
              h[RodaResponseHeaders::CONTENT_LENGTH] ||= '0'
            end
          else
            s = @status || default_status
            h[RodaResponseHeaders::CONTENT_LENGTH] ||= @length.to_s
          end

          [s, h, b]
        end

        # Return the rack response array using a given body.  Assumes a
        # 200 response status unless status has been explicitly set,
        # and doesn't add the content-length header or use the existing
        # body.
        def finish_with_body(body)
          set_default_headers
          [@status || default_status, @headers, body]
        end

        # Return the default response status to be used when the body
        # has been written to. This is split out to make overriding
        # easier in plugins.
        def default_status
          200
        end

        # Show response class, status code, response headers, and response body
        def inspect
          "#<#{self.class.inspect} #{@status.inspect} #{@headers.inspect} #{@body.inspect}>"
        end

        # Set the Location header to the given path, and the status
        # to the given status.  Example:
        #
        #   response.redirect('/foo', 301)
        #   response.redirect('/bar')
        def redirect(path, status = 302)
          @headers[RodaResponseHeaders::LOCATION] = path
          @status  = status
          nil
        end

        # Return the Roda class related to this response.
        def roda_class
          self.class.roda_class
        end

        # Write to the response body.  Returns nil.
        #
        #   response.write('foo')
        def write(str)
          s = str.to_s
          @length += s.bytesize
          @body << s
          nil
        end

        private

        if defined?(Rack::Headers) && Rack::Headers.is_a?(Class)
          DEFAULT_HEADERS = Rack::Headers[{RodaResponseHeaders::CONTENT_TYPE => "text/html".freeze}].freeze

          # Use Rack::Headers for headers by default on Rack 3
          def _initialize_headers
            # RODA4: Use {} always, add plugin for using Rack::Headers
            Rack::Headers.new
          end
        else
          DEFAULT_HEADERS = {RodaResponseHeaders::CONTENT_TYPE => "text/html".freeze}.freeze

          # Use plain hash for headers by default on Rack 1-2
          def _initialize_headers
            {}
          end
        end

        if Rack.release < '2.0.2'
          # Don't use a content length for empty 205 responses on
          # rack 1, as it violates Rack::Lint in that version.
          def empty_205_headers(headers)
            headers.delete(RodaResponseHeaders::CONTENT_TYPE)
            headers.delete(RodaResponseHeaders::CONTENT_LENGTH)
          end
        else
          # Set the content length for empty 205 responses to 0
          def empty_205_headers(headers)
            headers.delete(RodaResponseHeaders::CONTENT_TYPE)
            headers[RodaResponseHeaders::CONTENT_LENGTH] = '0'
          end
        end

        # For each default header, if a header has not already been set for the
        # response, set the header in the response.
        def set_default_headers
          h = @headers
          default_headers.each do |k,v|
            h[k] ||= v
          end
        end
      end
    end
  end
end
