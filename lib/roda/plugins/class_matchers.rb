# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The class_matchers plugin allows you do define custom regexps and
    # conversion procs to use for specific classes.  For example, if you
    # have multiple routes similar to:
    #
    #   r.on /(\d\d\d\d)-(\d\d)-(\d\d)/ do |y, m, d|
    #     date = Date.new(y.to_i, m.to_i, d.to_i)
    #     # ...
    #   end
    #
    # You can register a Date class matcher for that regexp:
    #
    #   class_matcher(Date, /(\d\d\d\d)-(\d\d)-(\d\d)/) do |y, m, d|
    #     Date.new(y.to_i, m.to_i, d.to_i)
    #   end
    #
    # And then use the Date class as a matcher, and it will yield a Date object:
    #
    #   r.on Date do |date|
    #     # ...
    #   end
    #
    # This is useful to DRY up code if you are using the same type of pattern and
    # type conversion in multiple places in your application. You can have the
    # block return an array to yield multiple captures.
    #
    # If you have a segment match the passed regexp, but decide during block
    # processing that you do not want to treat it as a match, you can have the
    # block return nil or false.  This is useful if you want to make sure you
    # are using valid data:
    #
    #   class_matcher(Date, /(\d\d\d\d)-(\d\d)-(\d\d)/) do |y, m, d|
    #     y = y.to_i
    #     m = m.to_i
    #     d = d.to_i
    #     Date.new(y, m, d) if Date.valid_date?(y, m, d)
    #   end
    #
    # The second argument to class_matcher can be a class already registered
    # as a class matcher. This can DRY up code that wants a conversion
    # performed by an existing class matcher:
    #
    #   class_matcher Employee, Integer do |id|
    #     Employee[id]
    #   end
    #
    # With the above example, the Integer matcher performs the conversion to
    # integer, so +id+ is yielded as an integer.  The block then looks up the
    # employee with that id.  If there is no employee with that id, then
    # the Employee matcher will not match.
    #
    # If using the symbol_matchers plugin, you can provide a recognized symbol
    # matcher as the second argument to class_matcher, and it will work in
    # a similar manner:
    #
    #   symbol_matcher(:employee_id, /E-(\d{6})/) do |employee_id|
    #     employee_id.to_i
    #   end
    #   class_matcher Employee, :employee_id do |id|
    #     Employee[id]
    #   end
    #
    # Blocks passed to the class_matchers plugin are evaluated in route
    # block context.
    #
    # When passing a regexp as a matcher, to class_matcher, you can provide a
    # <tt>segment: true</tt> option to speed up the matching on Ruby 2.4+:
    #
    #   symbol_matcher(:employee_id, /E-(\d{6})/, segment: true) do |employee_id|
    #     employee_id.to_i
    #   end
    #
    # Use of <tt>segment: true</tt> requires that the regexp not match more than
    # one segment (i.e. it cannot match +/+). Additionally, the entire segment will
    # be captured, so any capture groups in the regexp will be ignored.
    #
    # This plugin does not work with the params_capturing plugin, as it does not
    # offer the ability to associate block arguments with named keys.
    module ClassMatchers
      def self.load_dependencies(app)
        app.plugin :_symbol_class_matchers
      end

      def self.configure(app)
        app.opts[:class_matchers] ||= {
          Integer=>[/(\d{1,100})/, /\A\/(\d{1,100})(?=\/|\z)/, :_convert_class_Integer].freeze,
          String=>[/([^\/]+)/, nil, nil].freeze
        }
      end

      module ClassMethods
        # Set the matcher and block to use for the given class.
        # The matcher can be a regexp, registered class matcher, or registered symbol
        # matcher (if using the symbol_matchers plugin).
        #
        # If providing a regexp, the block given will be called with all regexp captures.
        # If providing a registered class or symbol, the block will be called with the
        # captures returned by the block for the registered class or symbol, or the regexp
        # captures if no block was registered with the class or symbol. In either case,
        # if a block is given, it should return an array with the captures to yield to
        # the match block.
        def class_matcher(klass, matcher, opts=OPTS, &block)
          _symbol_class_matcher(Class, klass, matcher, block, opts) do |meth, (_, regexp, convert_meth, consume_meth)|
            if regexp
              if consume_meth == :_consume_single_segment
                define_method(meth){_consume_single_segment(regexp, convert_meth)}
              else
                define_method(meth){consume(regexp, convert_meth)}
              end
            else
              define_method(meth){_consume_segment(convert_meth)}
            end
          end
        end

        # Freeze the class_matchers hash when freezing the app.
        def freeze
          opts[:class_matchers].freeze
          super
        end
      end

      module RequestMethods
        # Use faster approach for segment matching.  This is used for
        # matchers based on the String class matcher, and avoids the
        # use of regular expressions for scanning.
        def _consume_segment(convert_meth)
          rp = @remaining_path
          if _match_class_String
            if convert_meth
              if captures = scope.send(convert_meth, @captures.pop)
                if captures.is_a?(Array)
                  @captures.concat(captures)
                else
                  @captures << captures
                end
              else
                @remaining_path = rp
                nil
              end
            else
              true
            end
          end
        end
      end
    end

    register_plugin(:class_matchers, ClassMatchers)
  end
end
