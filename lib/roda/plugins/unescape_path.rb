# frozen-string-literal: true

require 'rack/utils'

#
class Roda
  module RodaPlugins
    # The unescape_path plugin decodes a URL-encoded path
    # before routing.  This fixes routing when the slashes
    # are URL-encoded as %2f and returns decoded parameters
    # when matched by symbols or regexps.
    #
    #   plugin :unescape_path
    #
    #   route do |r|
    #     # Assume /b/a URL encoded at %2f%62%2f%61
    #     r.on :x, /(.)/ do |*x|
    #       # x => ['b', 'a']
    #     end
    #   end
    module UnescapePath
      module RequestMethods
        # Make sure the matched path calculation handles the unescaping
        # of the remaining path.
        def matched_path
          e = @env
          _unescape_path(e["SCRIPT_NAME"] + e["PATH_INFO"]).chomp(@remaining_path)
        end

        private

        # Unescape the path.
        def _remaining_path(env)
          _unescape_path(super)
        end

        # Rack::Utils.unescape decodes + as a space, which is only
        # correct for form data, so escape + first to keep it.
        def _unescape_path(path)
          Rack::Utils.unescape(path.gsub('+', '%2B'))
        end
      end
    end

    register_plugin(:unescape_path, UnescapePath)
  end
end
