# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The early_hints plugin adds the +send_early_hints+ method for sending
    # 103 Early Hints responses using the +rack.early_hints+ environment variable.
    # Early hints allow clients to preload necessary files before receiving
    # the response.
    module EarlyHints
      module InstanceMethods
        # Send given hash of Early Hints using the +rack.early_hints+ environment variable,
        # currenly supported by puma and falcon.  hash given should generally have the single
        # key 'Link', and a string or array of strings for each of the early hints.
        def send_early_hints(hash)
          if eh_proc = env['rack.early_hints']
            eh_proc.call(hash)
          end
        end
      end
    end

    register_plugin(:early_hints, EarlyHints)
  end
end
