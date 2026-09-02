# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The optimized_string_matchers plugin adds two optimized matcher methods,
    # +r.on_branch+ and +r.is_exactly+.  +r.on_branch+ is an optimized version of
    # +r.on+ that only accepts a single string, and +r.is_exactly+ is an
    # optimized version of +r.is+ that only accepts a single string.
    #
    #   plugin :optimized_string_matchers
    #
    #   route do |r|
    #     r.on_branch "x" do
    #       # matches /x and paths starting with /x/
    #       r.is_exactly "y" do
    #         # matches /x/y
    #       end
    #     end
    #   end
    #
    # If you are using the placeholder_string_matchers plugin, note
    # that both of these methods only work with plain strings, not
    # with strings with embedded colons for capturing.  Matching will work
    # correctly in such cases, but the captures will not be yielded to the
    # match blocks.
    module OptimizedStringMatchers
      module RequestMethods
        # Optimized version of +on+ that only supports a single string.
        def on_branch(s)
          rp = @remaining_path
          if _match_string(s)
            always{yield}
            @remaining_path = rp
          end
        end

        # Optimized version of +is+ that only supports a single string.
        def is_exactly(s)
          rp = @remaining_path
          if _match_string(s)
            if @remaining_path.empty?
              always{yield}
            end
            @remaining_path = rp
          end
        end
      end
    end

    register_plugin(:optimized_string_matchers, OptimizedStringMatchers)
  end
end
