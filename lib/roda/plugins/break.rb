# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The break plugin supports calling break inside a match block, to
    # return from the block and continue in the routing tree, restoring
    # the remaining path so that future matchers operating on the path
    # operate as expected.
    #
    #   plugin :break
    #
    #   route do |r|
    #     r.on "foo", :bar do |bar|
    #       break if bar == 'baz'
    #       "/foo/#{bar} (not baz)"
    #     end
    #
    #     r.on "foo/baz" do
    #       "/foo/baz"
    #     end
    #   end
    #
    # This provides the same basic feature as the pass plugin, but
    # uses Ruby's standard control flow primitive instead of a
    # separate method.
    module Break
      module RequestMethods
        private

        # Handle passing inside the match block.
        def always
          rp = @remaining_path
          super
        ensure
          @remaining_path = rp
        end

        # Handle break inside match blocks, restoring remaining path.
        def if_match(_)
          rp = @remaining_path
          super
        ensure
          @remaining_path = rp
        end
      end
    end

    register_plugin(:break, Break)
  end
end
