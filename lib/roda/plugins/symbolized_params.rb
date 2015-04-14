class Roda
  module RodaPlugins
    # The symbolized_params plugin adds a +params+ instance
    # method which returns a copy of the request params hash
    # with symbolized keys.
    # Example:
    #
    #   plugin :symbolized_keys
    #
    #   route do |r|
    #     params[:foo]
    #   end
    #
    # The params hash is initialized lazily, so you only pay
    # the penalty of copying the request params if you call
    # the +params+ method.
    #
    # This differs from the indifferent_params plugin, which
    # keeps string keys in +params+, but allows the +Hash#[]+
    # operator to accept symbols. On the other hand, with the
    # symbolized_params plugin +params+ has actual symbol
    # keys, which allows you to use other Hash methods like
    # +Hash#fetch+ with symbol keys, and use +params+ as
    # keyword arguments.
    #
    # Since Symbol garbage collection was introduced only in
    # Ruby 2.2.0, using this plugin is *not* recommended if
    # you're running Ruby version lower than 2.2.0. This is
    # because prior to 2.2.0 all symbols stay in memory
    # indefinitely (or until the process is killed), which
    # can lead to denial of service attacks.
    module SymbolizedParams
      module InstanceMethods
        # A copy of the request params with symbolized keys.
        def params
          @_params ||= symbolized_params(request.params)
        end

        private

        # Recursively process the request params and symbolize
        # the keys, leaving other values alone.
        def symbolized_params(params)
          case params
          when Hash
            hash = {}
            params.each { |k, v| hash[k.to_sym] = symbolized_params(v) }
            hash
          when Array
            params.map { |x| symbolized_params(x) }
          else
            params
          end
        end
      end
    end

    register_plugin(:symbolized_params, SymbolizedParams)
  end
end
