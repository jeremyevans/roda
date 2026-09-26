# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The default_status plugin accepts a block which should
    # return a response status integer. This integer will be used as
    # the default response status (usually 200) if the body has been
    # written to, and you have not explicitly set a response status.
    #
    # Example:
    #
    #   # Use 201 default response status for all requests
    #   plugin :default_status do
    #     201
    #   end
    module DefaultStatus
      def self.configure(app, &block)
        raise RodaError, "default_status plugin requires a block" unless block
        if check_arity = app.opts.fetch(:check_arity, true)
          # RODA4: Remove support for :check_arity, default to false behavior
          unless block.arity == 0
            if check_arity == :warn
              RodaPlugins.warn "Arity mismatch in block passed to plugin :default_status. Expected Arity 0, but arguments required for #{block.inspect}"
            end
            b = block
            block = lambda{instance_exec(&b)} # Fallback
          end
        end
        app::RodaResponse.send(:define_method, :default_status, &block)
      end
    end

    register_plugin(:default_status, DefaultStatus)
  end
end
