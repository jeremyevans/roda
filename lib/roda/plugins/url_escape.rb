# frozen-string-literal: true

require 'rack/utils'

#
class Roda
  module RodaPlugins
    # The url_escape plugin add url_escape and url_unescape methods
    # to the route block scope.
    #
    #   plugin :url_escape
    #
    #   route do |r|
    #     link = "/path/q=#{url_escape(r.params["some_param"])}"
    #     response_body(link)
    #   end
    module UrlEscape
      module InstanceMethods
        if RUBY_VERSION >= '2'
          define_method(:url_escape, Rack::Utils.instance_method(:escape))
          define_method(:url_unescape, Rack::Utils.instance_method(:unescape))
        # :nocov:
        else
          def url_escape(v)
            Rack::Utils.escape(v)
          end

          def url_unescape(v)
            Rack::Utils.unescape(v)
          end
        end
        # :nocov:
      end
    end

    register_plugin(:url_escape, UrlEscape)
  end
end

