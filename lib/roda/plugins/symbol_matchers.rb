# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The symbol_matchers plugin allows you do define custom regexps to use
    # for specific symbols.  For example, if you have a route such as:
    #
    #   r.on :username do |username|
    #     # ...
    #   end
    #
    # By default this will match all nonempty segments.  However, if your usernames
    # must be 6-20 characters, and can only contain +a-z+ and +0-9+, you can do:
    #
    #   plugin :symbol_matchers
    #   symbol_matcher :username, /([a-z0-9]{6,20})/
    #
    # Then the route will only if the path is +/foobar123+, but not if it is
    # +/foo+, +/FooBar123+, or +/foobar_123+.
    #
    # You can provide a <tt>segment: true</tt> option to symbol_matcher to speed up
    # the matching on Ruby 2.4+:
    #
    #   symbol_matcher :username, /([a-z0-9]{6,20})/, segment: true
    #
    # Use of <tt>segment: true</tt> requires that the regexp not match more than
    # one segment (i.e. it cannot match +/+). Additionally, the entire segment will
    # be captured, so any capture groups in the regexp will be ignored.
    #
    # By default, this plugin sets up the following symbol matchers:
    #
    # :d :: <tt>/(\d+)/</tt>, a decimal segment
    # :rest :: <tt>/(.*)/</tt>, all remaining characters, if any
    # :w :: <tt>/(\w+)/</tt>, an alphanumeric segment
    #
    # If the placeholder_string_matchers plugin is loaded, this feature also applies to
    # placeholders in strings, so the following:
    #
    #   r.on "users/:username" do |username|
    #     # ...
    #   end
    #
    # Would match +/users/foobar123+, but not +/users/foo+, +/users/FooBar123+,
    # or +/users/foobar_123+.
    #
    # If using this plugin with the params_capturing plugin, this plugin should
    # be loaded first.
    #
    # You can provide a block when calling +symbol_matcher+, and it will be called
    # for all matches to allow for type conversion:
    #
    #   symbol_matcher(:date, /(\d\d\d\d)-(\d\d)-(\d\d)/) do |y, m, d|
    #     Date.new(y.to_i, m.to_i, d.to_i)
    #   end
    #
    #   route do |r|
    #     r.on :date do |date|
    #       # date is an instance of Date
    #     end
    #   end
    #
    # If you have a segment match the passed regexp, but decide during block
    # processing that you do not want to treat it as a match, you can have the
    # block return nil or false.  This is useful if you want to make sure you
    # are using valid data:
    #
    #   symbol_matcher(:date, /(\d\d\d\d)-(\d\d)-(\d\d)/) do |y, m, d|
    #     y = y.to_i
    #     m = m.to_i
    #     d = d.to_i
    #     Date.new(y, m, d) if Date.valid_date?(y, m, d)
    #   end
    #
    # You can have the block return an array to yield multiple captures.
    #
    # The second argument to symbol_matcher can be a symbol already registered
    # as a symbol matcher. This can DRY up code that wants a conversion
    # performed by an existing class matcher or to use the same regexp:
    #
    #   symbol_matcher :employee_id, :d do |id|
    #     id.to_i
    #   end
    #   symbol_matcher :employee, :employee_id do |id|
    #     Employee[id]
    #   end
    #
    # With the above example, the :d matcher matches only decimal strings, but
    # yields them as string.  The registered :employee_id matcher converts the
    # decimal string to an integer.  The registered :employee matcher builds
    # on that and uses the integer to lookup the related employee.  If there is
    # no employee with that id, then the :employee matcher will not match.
    #
    # If using the class_matchers plugin, you can provide a recognized class
    # matcher as the second argument to symbol_matcher, and it will work in
    # a similar manner:
    #
    #   symbol_matcher :employee, Integer do |id|
    #     Employee[id]
    #   end
    #
    # Blocks passed to the symbol matchers plugin are evaluated in route
    # block context.
    #
    # If providing a block to the symbol_matchers plugin, the symbol may 
    # not work with the params_capturing plugin. Note that the use of
    # symbol matchers inside strings when using the placeholder_string_matchers
    # plugin only uses the regexp, it does not respect the conversion blocks
    # registered with the symbols.
    module SymbolMatchers
      def self.load_dependencies(app)
        app.plugin :_symbol_regexp_matchers
        app.plugin :_symbol_class_matchers
      end

      def self.configure(app)
        app.opts[:symbol_matchers] ||= {}
        app.symbol_matcher(:d, /(\d+)/, segment: true)
        app.symbol_matcher(:w, /(\w+)/, segment: true)
        app.symbol_matcher(:rest, /(.*)/)
      end

      module ClassMethods
        # Set the matcher and block to use for the given class.
        # The matcher can be a regexp, registered symbol matcher, or registered class
        # matcher (if using the class_matchers plugin).
        #
        # If providing a regexp, the block given will be called with all regexp captures.
        # If providing a registered symbol or class, the block will be called with the
        # captures returned by the block for the registered symbol or class, or the regexp
        # captures if no block was registered with the symbol or class. In either case,
        # if a block is given, it should return an array with the captures to yield to
        # the match block.
        def symbol_matcher(s, matcher, opts=OPTS, &block)
          _symbol_class_matcher(Symbol, s, matcher, block, opts) do |meth, array|
            define_method(meth){array}
          end

          nil
        end

        # Freeze the class_matchers hash when freezing the app.
        def freeze
          opts[:symbol_matchers].freeze
          super
        end
      end

      module RequestMethods
        private

        # Use regular expressions to the symbol-specific regular expression
        # if the symbol is registered.  Otherwise, call super for the default
        # behavior.
        def _match_symbol(s)
          meth = :"match_symbol_#{s}"
          if respond_to?(meth, true)
            # Allow calling private match methods
            _, re, convert_meth, consume_meth = send(meth)
            if re
              send(consume_meth, re, convert_meth)
            else
              # defined in class_matchers plugin
              _consume_segment(convert_meth)
            end
          else
            super
          end
        end

        # Return the symbol-specific regular expression if one is registered.
        # Otherwise, call super for the default behavior.
        def _match_symbol_regexp(s)
          meth = :"match_symbol_#{s}"
          if respond_to?(meth, true)
            # Allow calling private match methods
            re, = send(meth)
            re
          else
            super
          end
        end
      end
    end

    register_plugin(:symbol_matchers, SymbolMatchers)
  end
end
