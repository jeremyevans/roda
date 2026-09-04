# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The params_capturing_restore plugin allows the params_capturing plugin
    # to work with the use of +r.pass+ (pass plugin) or +break+ (break plugin)
    # inside a block that uses param capturing, restoring the previous state of
    # the params.
    #
    # This is not done by the params_capturing plugin as it requires significant
    # extra work for every param capturing block, and most users of the
    # params_capturing plugin are not using the pass or break plugins.
    module ParamsCapturingRestore
      REQUEST_INSTANCE_VARIABLES = [:@_params_captures_restore].freeze

      ABSENT = Object.new.freeze
      private_constant :ABSENT

      def self.load_dependencies(app)
        app.plugin :params_capturing
      end

      module RequestMethods
        private

        # Restore previous state of the params before capturing when
        # the block exits.
        def if_match(args)
          params = self.params
          num_captures = params['captures'].length
          old_params = nil

          super do |*a|
            old_params = @_params_captures_restore
            @_params_captures_restore = nil
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

          captures = params['captures']
          if num_captures != captures.length
            captures.slice!(num_captures, 1000000)
          end
        end

        # Record the original value of the params before calling super
        # to update the params.
        def _set_params_captures(a)
          restore = @_params_captures_restore = []
          @_params_captures.zip(a).each do |k,v|
            restore << k << params.fetch(k, ABSENT)
          end

          super
        end
      end
    end

    register_plugin(:params_capturing_restore, ParamsCapturingRestore)
  end
end

