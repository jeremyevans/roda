class Roda
  module RodaPlugins
    # The indifferent_params plugin adds a +params+ instance
    # method which returns a copy of the request params hash
    # that will automatically convert symbols to strings.
    # Example:
    #
    #   plugin :indifferent_params
    #
    #   route do |r|
    #     params[:foo]
    #   end
    #
    # The params hash is initialized lazily, so you only pay
    # the penalty of copying the request params if you call
    # the +params+ method.
    #
    # Note that there is a rack-indifferent gem that
    # automatically makes rack use indifferent params. Using
    # rack-indifferent is faster and has some other minor
    # advantages over the indifferent_params plugin, though
    # it affects rack itself instead of just the Roda app that
    # you load the plugin into.
    module IndifferentParams
      module InstanceMethods

        # todo: better way of handling `params` between json plugin and this
        def self.included base
          unless base.instance_methods.include? :params
            base.class_eval do

              # A copy of the request params that will automatically
              # convert symbols to strings.
              def params
                @_params ||= indifferent_params(request.params)
              end
            end
          end
        end

        private

        # Recursively process the request params and convert
        # hashes to support indifferent access, leaving
        # other values alone.
        def indifferent_params(params)
          case params
          when Hash
            hash = Hash.new{|h, k| h[k.to_s] if Symbol === k}
            params.each{|k, v| hash[k] = indifferent_params(v)}
            hash
          when Array
            params.map{|x| indifferent_params(x)}
          else
            params
          end
        end
      end
    end

    register_plugin(:indifferent_params, IndifferentParams)
  end
end
