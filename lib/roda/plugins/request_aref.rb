# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The request_aref plugin allows for custom handling of the r[] and r[]=
    # methods (where r is the Request instance).  In the current version of
    # rack, these methods are deprecated, but the deprecation message is only
    # printed in verbose mode.  This plugin can allow for handling calls to
    # these methods in one of three ways:
    #
    # :allow :: Allow the method calls without a deprecation, which is the
    #           historical behavior
    # :warn :: Always issue a deprecation message by calling +warn+, not just
    #          in verbose mode.
    # :raise :: Raise an error if either method is called
    module RequestAref
      # Make #[] and #[]= methods work as configured by aliasing the appropriate
      # request_a(ref|set)_* methods to them.
      def self.configure(app, setting)
        case setting
        when :allow, :raise, :warn
          app::RodaRequest.class_exec do
            alias_method(:[],  :"request_aref_#{setting}")
            alias_method(:[]=, :"request_aset_#{setting}")
            public :[], :[]=
          end
        else
          raise RodaError, "Unsupport request_aref plugin setting: #{setting.inspect}"
        end
      end

      # Exception class raised when #[] or #[]= are called when the
      # :raise setting is used.
      class Error < RodaError
      end

      module RequestMethods
        private

        # Allow #[] calls
        def request_aref_allow(k)
          params[k.to_s]
        end

        # Always warn on #[] calls
        def request_aref_warn(k)
          warn("#{self.class}#[] is deprecated, use #params.[] instead")
          params[k.to_s]
        end

        # Raise error on #[] calls
        def request_aref_raise(k)
          raise Error, "#{self.class}#[] has been removed, use #params.[] instead"
        end

        # Allow #[]= calls
        def request_aset_allow(k, v)
          params[k.to_s] = v
        end

        # Always warn on #[]= calls
        def request_aset_warn(k, v)
          warn("#{self.class}#[]= is deprecated, use #params.[]= instead")
          params[k.to_s] = v
        end

        # Raise error on #[]= calls
        def request_aset_raise(k, v)
          raise Error, "#{self.class}#[]= has been removed, use #params.[]= instead"
        end
      end
    end

    register_plugin(:request_aref, RequestAref)
  end
end
