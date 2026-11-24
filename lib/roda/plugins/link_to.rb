# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The link_to plugin adds the +link_to+ instance method, which can be used for constructing
    # HTML links (+a+ tag with +href+ attribute).
    #
    # The simplest usage of +link_to+ is passing the body and the location to link to as strings:
    #
    #   link_to("body", "/path")
    #   # => "<a href=\"/path\">body</a>"
    #
    # The link_to plugin depends on the path plugin, and allows you to pass symbols for named paths:
    #
    #   # Class level
    #   path :foo, "/path/to/too"
    #
    #   # Instance level
    #   link_to("body", :foo)
    #   # => "<a href=\"/path/to/foo\">body</a>"
    #
    # It also allows you to pass instances of classes that you have registered with the path plugin:
    #
    #   # Class level
    #   A = Struct.new(:id)
    #   path A do
    #     "/path/to/a/#{id}"
    #   end
    #
    #   # Instance level
    #   link_to("body", A.new(1))
    #   # => "<a href=\"/path/to/a/1\">body</a>"
    #
    # To set additional HTML attributes on the +a+ tag, you can pass them as an options hash:
    #
    #   link_to("body", "/path", foo: "bar")
    #   # => "<a href=\"/path\" foo=\"bar\">body</a>"
    #
    # If the body is nil, it will be set to the same as the path:
    #
    #   link_to(nil, "/path")
    #   # => "<a href=\"/path\">/path</a>"
    #
    # The plugin will automatically HTML escape the path and any HTML attribute values, using the h plugin:
    #
    #   link_to("body", "/path?a=1&b=2", foo: '"bar"')
    #   # => "<a href=\"/path?a=1&amp;b=2\" foo=\"&quot;bar&quot;\">body</a>"
    #
    # Note that the body and the keys in the attributes are not escaped, so
    # you should not pass an untrusted body or untrusted keys in attributes.
    module LinkTo
      def self.load_dependencies(app)
        app.plugin :h
        app.plugin :path
      end

      module InstanceMethods
        # Return a string with an HTML +a+ tag with an +href+ attribute. See LinkTo
        # module documentation for details.
        def link_to(body, href, attributes=OPTS)
          case href
          when Symbol
            href = public_send(:"#{href}_path")
          when String
            # nothing
          else
            href = path(href)
          end

          href = h(href)

          body = href if body.nil?

          buf = String.new << "<a href=\"#{href}\""
          attributes.each do |k, v|
            buf << " " << k.to_s << "=\"" << h(v) << "\""
          end
          buf << ">" << body << "</a>"
        end
      end
    end

    register_plugin(:link_to, LinkTo)
  end
end
