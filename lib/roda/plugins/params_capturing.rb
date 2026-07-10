# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The params_capturing plugin makes symbol matchers
    # update the request params with the value of the captured segments,
    # using the matcher as the key:
    #
    #   plugin :params_capturing
    #
    #   route do |r|
    #     # GET /foo/123/abc/67
    #     r.on("foo", :bar, :baz, :quux) do
    #       r.params['bar'] #=> '123'
    #       r.params['baz'] #=> 'abc'
    #       r.params['quux'] #=> '67'
    #     end
    #   end
    #
    # Note that this updating of the request params using the matcher as
    # the key is only done if all arguments to the matcher are symbols
    # or strings.
    #
    # All matchers will update the request params by adding all
    # captured segments to the +captures+ key:
    #
    #   r.on(:x, /(\d+)\/(\w+)/, :y) do
    #     r.params['x'] #=> nil
    #     r.params['y'] #=> nil
    #     r.params['captures'] #=> ["foo", "123", "abc", "67"]
    #   end
    #
    # Note that the request params +captures+ entry will be appended to with
    # each nested match:
    #
    #   r.on(:w) do
    #     r.on(:x) do
    #       r.on(:y) do
    #         r.on(:z) do
    #           r.params['captures'] # => ["foo", "123", "abc", "67"]
    #         end
    #       end
    #     end
    #   end
    #
    # Note that any existing params captures entry will be overwritten
    # by this plugin.  You can use +r.GET+ or +r.POST+ to get the underlying
    # entry, depending on how it was submitted.
    #
    # This plugin will also handle string matchers with placeholders if
    # the placeholder_string_matchers plugin is loaded before this plugin.
    #
    # Also note that this plugin will not work correctly if you are using
    # the symbol_matchers plugin with custom symbol matching and are using
    # symbols that capture multiple values or no values.
    module ParamsCapturing
      REQUEST_INSTANCE_VARIABLES = [:@_params_captures].freeze

      module RequestMethods
        # Lazily initialize captures entry when params is called.
        def params
          ret = super
          ret['captures'] ||= []
          ret
        end

        private

        # Add the capture names from this string to list of param
        # capture names if param capturing.
        def _match_string(str)
          cap_len = @captures.length

          if (ret = super) && (pc = @_params_captures) && (cap_len != @captures.length)
            # Handle use with placeholder_string_matchers plugin
            pc.concat(str.scan(/(?<=:)\w+/))
          end

          ret
        end

        # Add the symbol to the list of param capture names if param capturing.
        def _match_symbol(sym)
          if pc = @_params_captures
            pc << sym.to_s
          end
          super
        end

        # If all arguments are strings or symbols, turn on param capturing during
        # the matching, but turn it back off before yielding to the block.  Add
        # any captures to the params based on the param capture names added by
        # the matchers.
        def if_match(args)
          params = self.params

          if args.all?{|x| x.is_a?(String) || x.is_a?(Symbol)}
            pc = @_params_captures = []
          end

          super do |*a|
            if pc
              @_params_captures = nil
              pc.zip(a).each do |k,v|
                params[k] = v
              end
            end
            params['captures'].concat(a) 
            yield(*a)
          end
        end
      end
    end

    register_plugin(:params_capturing, ParamsCapturing)
  end
end
