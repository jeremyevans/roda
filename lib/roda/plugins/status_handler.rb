# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The status_handler plugin adds a +status_handler+ method which sets a
    # block that is called whenever a response with the relevant response code
    # with an empty body would be returned.
    #
    # This plugin does not support providing the blocks with the plugin call;
    # you must provide them to status_handler calls afterwards:
    #
    #   plugin :status_handler
    #
    #   status_handler(403) do
    #     "You are forbidden from seeing that!"
    #   end
    #
    #   status_handler(404) do
    #     "Where did it go?"
    #   end
    #
    #   status_handler(405, keep_headers: ['Accept']) do
    #     "Use a different method!"
    #   end
    #
    # Before a block is called, any existing headers on the response will be
    # cleared, unless the +:keep_headers+ option is used.  If the +:keep_headers+
    # option is used, the value should be an array, and only the headers listed
    # in the array will be kept.
    module StatusHandler
      CLEAR_HEADERS = :clear.to_proc
      private_constant :CLEAR_HEADERS

      def self.configure(app)
        app.opts[:status_handler] ||= {}
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :status_handler, name: :status_handlers)

        # Install the given block as a status handler for the given HTTP response code.
        def status_handler(code, opts=OPTS, &block)
          # For backwards compatibility, pass request argument if block accepts argument
          arity = block.arity == 0 ? 0 : 1
          handle_headers = case keep_headers = opts[:keep_headers]
          when nil, false
            CLEAR_HEADERS
          when Array
            if Rack.release >= '3'
              keep_headers = keep_headers.map(&:downcase)
            end
            lambda{|headers| headers.delete_if{|k,_| !keep_headers.include?(k)}}
          else
            raise RodaError, "Invalid :keep_headers option"
          end

          meth = define_roda_method(:"_roda_status_handler__#{code}", arity, &block)
          status_handlers[code] = define_roda_method(:"_roda_status_handler_#{code}", 1) do |result|
            res = @_response
            res.status = result[0]
            handle_headers.call(res.headers)
            result.replace(_roda_handle_route{arity == 1 ? send(meth, @_request) : send(meth)})
          end
        end

        # Freeze the hash of status handlers so that there can be no thread safety issues at runtime.
        def freeze
          status_handlers.freeze
          super
        end
      end

      module InstanceMethods
        private

        # If routing returns a response we have a handler for, call that handler.
        def _roda_after_20__status_handler(result)
          if result && (meth = self.class.status_handlers[result[0]]) && (v = result[2]).is_a?(Array) && v.empty?
            send(meth, result)
          end
        end
      end
    end

    register_plugin(:status_handler, StatusHandler)
  end
end
