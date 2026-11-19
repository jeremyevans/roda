# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The disallow_multipart_parsing plugin disables the use of Rack's multipart
    # parser by +r.POST+ and +r.params+. This is recommended if the application
    # is not expected to receive file uploads, as it avoids all potential
    # security issues related to Rack's multipart parser (which has had numerous
    # security issues in the past). If a request attempts to parse a multipart
    # request body, a Roda::RodaPlugins::DisallowMultipartParsing::Error is raised.
    #
    # Usage:
    #
    #   plugin :disallow_multipart_parsing
    module DisallowMultipartParsing
      # Exception class used when a multipart request body is submitted.
      class Error < RodaError; end

      module RequestMethods
        # simplecov:disable
        if Rack::Request.private_method_defined?(:multipart_parser) # Rack 3.3+
          def multipart_parser
            # Assume that if this method is called, it is only when a parse
            # is about to be attempted
            raise Error, "multipart request body submitted"
          end
          private :multipart_parser
        # simplecov:enable
        else
          if Rack.release < "2"
            def parse_multipart(env)
              raise_for_multipart_content_type
              super
            end
            private :parse_multipart
          elsif Rack.release < "3.1"
            def parse_multipart
              raise_for_multipart_content_type
              super
            end
            private :parse_multipart
          elsif Rack.release < "3.2"
            def POST
              raise_for_multipart_content_type
              super
            end
          else # Rack 3.2
            def form_pairs
              raise_for_multipart_content_type
              super
            end
          end

          private

          # Raise an Error if the content type indicates multipart.
          def raise_for_multipart_content_type
            unless @multipart_content_type_checked
              if (ct = content_type) && ct.match(/\Amultipart\//i)
                raise Error, "multipart request body submitted"
              end
              @multipart_content_type_checked = true
            end
          end
        end
      end
    end

    register_plugin(:disallow_multipart_parsing, DisallowMultipartParsing)
  end
end
