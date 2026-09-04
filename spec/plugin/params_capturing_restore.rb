# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The params_capturing_restore plugin allows the params_capturing plugin
    # to work with the use of +r.pass+ (pass plugin) or +break+ (break plugin)
    # inside a block that uses param capturing. This is not done by the
    # params_capturing as it requires significant extra work for every param
    # capturing block, and most users of the params_capturing plugin are not
    # using the pass or break plugins.
    module ParamsCapturingRestore
      ABSENT = Object.new.freeze
      private_constant :ABSENT

      def self.load_dependencies(app)
        app.plugin :params_capturing
      end

      module RequestMethods
        private

        # If all arguments are strings or symbols, turn on param capturing during
        # the matching, but turn it back off before yielding to the block.  Add
        # any captures to the params based on the param capture names added by
        # the matchers.
        def if_match(args)
          params = self.params
          num_captures = params['captures'].length
          old_params = nil

          super do |*a|
            if pc = @_params_captures
              old_params = []
              pc.zip(a).each do |k,v|
                old_params << k << params.fetch(k, ABSENT)
              end
            end
            yield(*a)
          end
        ensure
          if old_params
            old_params.each_slice(2) do |k, v|
              if v == ABSENT
                params.delete(k)
              else
                params[k] = v
              end
            end
          end
          params['captures'].slice!(num_captures, 1000000)
        end
      end
    end

    register_plugin(:params_capturing_restore, ParamsCapturingRestore)
  end
end

