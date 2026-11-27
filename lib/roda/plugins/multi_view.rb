# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The multi_view plugin makes it easy to render multiple views, where the
    # view template is the same as the matched element.  It adds an +r.multi_view+
    # method, which takes an argument that is passed to +r.get+, and should
    # capture a single argument, which is treated as the template name to pass
    # to +view+.  This makes it possible to pass in:
    #
    # * An array of strings
    # * A set of strings
    # * A string-keyed hash
    # * A regexp with a single capture
    # * Other matcher that yields a single string
    #
    # For static strings, it's recommended to use a set of strings instead of an
    # array of strings, as that is better for performance.
    #
    # The multi_view plugin also offers a +multi_view_compile+ class method that
    # will take an array of view template names and construct a regexp that can
    # be passed to +r.multi_view+. However, the only reason to use this instead of
    # a set of strings is it supports cases where one of the array elements
    # contains a slash.
    #
    # Example:
    #
    #   plugin :multi_view
    #
    #   route do |r|
    #     r.multi_view(['foo', 'bar', 'baz'])
    #   end
    #
    #   # or:
    #
    #   route do |r|
    #     r.multi_view(/(foo|bar|baz)/)
    #   end
    #
    #   # or:
    #
    #   regexp = multi_view_compile(['foo', 'bar', 'baz'])
    #   route do |r|
    #     r.multi_view(regexp)
    #   end
    #
    #   # all are equivalent to:
    #
    #   route do |r|
    #     r.get 'foo' do
    #       view('foo')
    #     end
    #
    #     r.get 'bar' do
    #       view('bar')
    #     end
    #
    #     r.get 'baz' do
    #       view('baz')
    #     end
    #   end
    module MultiView
      # Depend on the render plugin, since this plugin only makes
      # sense when the render plugin is used.
      def self.load_dependencies(app)
        app.plugin :render
      end

      module ClassMethods
        # Given the array of view template names, return a regexp that will
        # match on any of the names and capture the matched name.
        def multi_view_compile(array)
          /(#{Regexp.union(array)})/
        end
      end

      module RequestMethods
        # Pass the argument to +get+, and assume if the matchers match that
        # there is one capture, and call view with that capture.
        def multi_view(arg)
          get(arg) do |page|
            scope.view(page)
          end
        end
      end
    end

    register_plugin(:multi_view, MultiView)
  end
end
