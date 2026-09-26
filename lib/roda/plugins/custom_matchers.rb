# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The custom_matchers plugin supports using arbitrary objects
    # as matchers, as long as the application has been configured
    # to accept such objects.
    #
    # After loading the plugin, support for custom matchers can be
    # configured using the +custom_matcher+ class method.  This
    # method is generally passed the class of the object you want
    # to use as a custom matcher, as well as a block.  The block
    # will be called in the context of the request instance
    # with the specific matcher used in the match method.
    #
    # Blocks can append to the captures in order to yield the appropriate
    # values to match blocks, or call request methods that append to the
    # captures.
    #
    # Example:
    #
    #   plugin :custom_matchers
    #   method_segment = Struct.new(:request_method, :next_segment)
    #   custom_matcher(method_segment) do |matcher|
    #     # self is the request instance ("r" yielded in the route block below)
    #     if matcher.request_method == self.request_method
    #       match(matcher.next_segment)
    #     end
    #   end
    #
    #   get_foo = method_segment.new('GET', 'foo') 
    #   post_any = method_segment.new('POST', String) 
    #   route do |r|
    #     r.on('baz') do
    #       r.on(get_foo) do
    #         # GET method, /baz/foo prefix
    #       end
    #
    #       r.is(post_any) do |seg|
    #         # for POST /baz/bar, seg is "bar"
    #       end
    #     end
    #
    #     r.on('quux') do
    #       r.is(get_foo) do
    #         # GET method, /quux/foo route
    #       end
    #
    #       r.on(post_any) do |seg|
    #         # for POST /quux/xyz, seg is "xyz"
    #       end
    #     end
    #   end
    module CustomMatchers
      def self.configure(app)
        app.opts[:custom_matchers] ||= OPTS
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :custom_matchers)

        def custom_matcher(match_class, &block)
          custom_matchers = Hash[self.custom_matchers]
          meth = custom_matchers[match_class] = custom_matchers[match_class] || :"_custom_matcher_#{match_class}"
          opts[:custom_matchers] = custom_matchers.freeze
          self::RodaRequest.send(:define_method, meth, &block)
          nil
        end
      end

      module RequestMethods
        private

        # Try custom matchers before calling super
        def unsupported_matcher(matcher)
          roda_class.custom_matchers.each do |match_class, meth|
            if match_class === matcher
              return send(meth, matcher)
            end
          end

          super
        end
      end
    end

    register_plugin(:custom_matchers, CustomMatchers)
  end
end

