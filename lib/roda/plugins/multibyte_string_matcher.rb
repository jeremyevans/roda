# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The multibyte_string_matcher plugin allows multibyte
    # strings to be used in matchers.  Roda's default string
    # matcher does not handle multibyte strings for performance
    # reasons.
    #
    # As browsers send multibyte characters in request paths URL
    # escaped, so this also loads the unescape_path plugin to
    # unescape the paths.
    #
    #   plugin :multibyte_string_matcher
    #
    #   path = "\xD0\xB8".force_encoding('UTF-8')
    #   route do |r|
    #     r.get path do
    #       # GET /%D0%B8
    #     end
    #
    #     r.get /y-(#{path})/u do |x|
    #       # GET /y-%D0%B8
    #       x # => path
    #     end
    #   end
    module MultibyteStringMatcher
      # Must load unescape_path plugin to decode multibyte
      # paths, which are submitted escaped.
      def self.load_dependencies(app)
        app.plugin :unescape_path
      end

      module RequestMethods
        private

        # Use multibyte safe string matcher, using the same
        # approach as in Roda 3.0.
        def _match_string(str)
          rp = @remaining_path
          if rp.start_with?("/#{str}")
            last = str.length + 1
            case rp[last]
            when "/"
              @remaining_path = rp[last, rp.length]
            when nil
              @remaining_path = ""
            end
          end
        end
      end
    end

    register_plugin(:multibyte_string_matcher, MultibyteStringMatcher)
  end
end
