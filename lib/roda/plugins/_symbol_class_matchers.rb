# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    module SymbolClassMatchers_
      module ClassMethods
        private

        # Backend of symbol_matcher and class_matcher.
        def _symbol_class_matcher(expected_class, obj, matcher, block, options=OPTS, &request_class_block)
          unless obj.is_a?(expected_class)
            raise RodaError, "Invalid type passed to class_matcher or symbol_matcher: #{matcher.inspect}"
          end

          if obj.is_a?(Symbol)
            type = "symbol"
            meth = :"match_symbol_#{obj}"
          else
            type = "class"
            meth = :"_match_class_#{obj}"
          end

          case matcher
          when Regexp
            regexp = matcher
            consume_regexp = self::RodaRequest.send(:consume_pattern, regexp)
          when Symbol
            unless opts[:symbol_matchers]
              raise RodaError, "cannot provide Symbol matcher to class_matcher unless using symbol_matchers plugin: #{matcher.inspect}"
            end

            regexp, consume_regexp, convert_meth, consume_meth = opts[:symbol_matchers][matcher]

            unless regexp
              raise RodaError, "unregistered symbol matcher given to #{type}_matcher: #{matcher.inspect}"
            end

            block = _merge_matcher_blocks(type, obj, block, convert_meth)
          when Class
            unless opts[:class_matchers]
              raise RodaError, "cannot provide Class matcher to symbol_matcher unless using class_matchers plugin: #{matcher.inspect}"
            end

            regexp, consume_regexp, convert_meth, consume_meth = opts[:class_matchers][matcher]
            unless regexp
              raise RodaError, "unregistered class matcher given to #{type}_matcher: #{matcher.inspect}"
            end
            block = _merge_matcher_blocks(type, obj, block, convert_meth)
          else
            raise RodaError, "unsupported matcher given to #{type}_matcher: #{matcher.inspect}"
          end

          if block.is_a?(Symbol)
            convert_meth = block
          elsif block
            convert_meth = :"_convert_#{type}_#{obj}"
            define_method(convert_meth, &block)
            private convert_meth
          end

          consume_meth ||= options[:segment] ? :_consume_single_segment : :consume
          array = opts[:"#{type}_matchers"][obj] = [regexp, consume_regexp, convert_meth, consume_meth].freeze

          self::RodaRequest.class_eval do
            class_exec(meth, array, &request_class_block)
            private meth
          end

          nil
        end

        # If both block and convert_meth are given, 
        # define a method for block, and then return a
        # proc that calls convert_meth first, and only calls
        # the newly defined method with the return values of convert_meth
        # if matcher_method returns a truthy value.
        # Otherwise, return convert_meth or block.
        def _merge_matcher_blocks(type, obj, block, convert_meth)
          if convert_meth
            if block
              convert_merge_meth = :"_convert_merge_#{type}_#{obj}"
              define_method(convert_merge_meth, &block)
              private convert_merge_meth

              proc do |*a|
                if captures = send(convert_meth, *a)
                  if captures.is_a?(Array)
                    send(convert_merge_meth, *captures)
                  else
                    send(convert_merge_meth, captures)
                  end
                end
              end
            else
              convert_meth
            end
          else
            block
          end
        end
      end
    end

    register_plugin(:_symbol_class_matchers, SymbolClassMatchers_)
  end
end

