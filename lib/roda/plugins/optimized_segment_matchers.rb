# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The optimized_segment_matchers plugin adds two optimized matcher methods,
    # +r.on_segment+ and +r.is_segment+.  +r.on_segment+ is an optimized version of
    # +r.on String+ that accepts no arguments and yields the next segment if there
    # is a segment. +r.is_segment+ is an optimized version of +r.is String+ that accepts
    # no arguments and yields the next segment only if it is the last segment.
    #
    #   plugin :optimized_segment_matchers
    #
    #   route do |r|
    #     r.on_segment do |x|
    #       # matches any segment (e.g. /a, /b, but not /)
    #       r.is_segment do |y|
    #         # matches only if final segment (e.g. /a/b, /b/c, but not /c, /c/d/, /c/d/e)
    #       end
    #     end
    #   end
    module OptimizedSegmentMatchers
      module RequestMethods
        # Optimized version of +r.on String+ that yields the next segment if there
        # is a segment.
        def on_segment
          rp = @remaining_path
          if rp.getbyte(0) == 47
            if last = rp.index('/', 1)
              return false if last == 1
              always do
                @remaining_path = rp[last, rp.length]
                yield rp[1, last-1]
              end
            elsif (len = rp.length) > 1
              always do
                @remaining_path = ""
                yield rp[1, len]
              end
            end
          end
        end

        # Optimized version of +r.is String+ that yields the next segment only if it
        # is the final segment.
        def is_segment
          rp = @remaining_path
          if rp.getbyte(0) == 47 && !rp.index('/', 1) && (len = rp.length) > 1
            always do
              @remaining_path = ""
              yield rp[1, len]
            end
          end
        end
      end
    end

    register_plugin(:optimized_segment_matchers, OptimizedSegmentMatchers)
  end
end
