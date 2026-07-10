# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # A permissions_policy plugin has been added that allows you to easily set a
    # Permissions-Policy header for the application, which browsers can use to
    # determine whether to allow specific functionality on the returned page
    # (mainly related to which JavaScript APIs the page is allowed to use).
    #
    # You would generally call the plugin with a block to set the default policy:
    #
    #   plugin :permissions_policy do |pp|
    #     pp.camera :none
    #     pp.fullscreen :self
    #     pp.clipboard_read :self, 'https://example.com'
    #   end
    #
    # Then, anywhere in the routing tree, you can customize the policy for just that
    # branch or action using the same block syntax:
    #
    #   r.get 'foo' do
    #     permissions_policy do |pp|
    #       pp.camera :self
    #     end
    #     # ...
    #   end
    #
    # In addition to using a block, you can also call methods on the object returned
    # by the method:
    #
    #   r.get 'foo' do
    #     permissions_policy.camera :self
    #     # ...
    #   end
    #
    # You can use the :default plugin option to set the default for all settings.
    # For example, to disallow all access for each setting by default:
    #
    #   plugin :permissions_policy, default: :none
    #
    # The following methods are available for configuring the permissions policy,
    # which specify the setting (substituting _ with -): 
    #
    # * accelerometer
    # * ambient_light_sensor
    # * autoplay
    # * bluetooth
    # * camera
    # * clipboard_read
    # * clipboard_write
    # * display_capture
    # * encrypted_media
    # * fullscreen
    # * geolocation
    # * gyroscope
    # * hid
    # * idle_detection
    # * keyboard_map
    # * magnetometer
    # * microphone
    # * midi
    # * payment
    # * picture_in_picture
    # * publickey_credentials_get
    # * screen_wake_lock
    # * serial
    # * sync_xhr
    # * usb
    # * web_share
    # * window_management
    #
    # All of these methods support any number of arguments, and each argument should
    # be one of the following values:
    #
    # :all :: Grants permission to all domains (must be only argument)
    # :none :: Does not allow permission at all (must be only argument)
    # :self :: Allows feature in current document and any nested browsing contexts
    #          that use the same domain as the current document.
    # :src :: Allows feature in current document and any nested browsing contexts
    #         that use the same domain as the src of the iframe.
    # String :: Specifies origin domain where access is allowed
    #
    # When calling a method with no arguments, the setting is removed from the policy instead
    # of being left empty, since all of these setting require at least one value.  Likewise,
    # if the policy does not have any settings, the header will not be added.
    #
    # Calling the method overrides any previous setting.  Each of the methods has +add_*+ and
    # +get_*+ methods defined. The +add_*+ method appends to any existing setting, and the +get_*+ method
    # returns the current value for the setting (this will be +:all+ if all domains are allowed, or
    # any array of strings/:self/:src).
    #
    #   permissions_policy.fullscreen :self, 'https://example.com'
    #   # fullscreen (self "https://example.com")
    #
    #   permissions_policy.add_fullscreen 'https://*.example.com'
    #   # fullscreen (self "https://example.com" "https://*.example.com")
    #
    #   permissions_policy.get_fullscreen
    #   # => [:self, "https://example.com", "https://*.example.com"]
    #
    # The clear method can be used to remove all settings from the policy. Empty policies
    # do not set any headers. You can use +response.skip_permissions_policy!+ to skip
    # setting a policy.  This is faster than calling +permissions_policy.clear+, since
    # it does not duplicate the default policy.
    module PermissionsPolicy
      RESPONSE_INSTANCE_VARIABLES = [:@permissions_policy, :@skip_permissions_policy].freeze

      SUPPORTED_SETTINGS = %w'
      accelerometer
      ambient-light-sensor
      autoplay
      bluetooth
      camera
      clipboard-read
      clipboard-write
      display-capture
      encrypted-media
      fullscreen
      geolocation
      gyroscope
      hid
      idle-detection
      keyboard-map
      magnetometer
      microphone
      midi
      payment
      picture-in-picture
      publickey-credentials-get
      screen-wake-lock
      serial
      sync-xhr
      usb
      web-share
      window-management
      '.each(&:freeze).freeze
      private_constant :SUPPORTED_SETTINGS

      # Represents a permissions policy.
      class Policy
        SUPPORTED_SETTINGS.each do |setting|
          meth = setting.tr('-', '_').freeze

          # Setting method name sets the setting value, or removes it if no args are given.
          define_method(meth) do |*args|
            if args.empty?
              @opts.delete(setting)
            else
              @opts[setting] = option_value(args)
            end
            nil
          end

          # add_* method name adds to the setting value, or clears setting if no values
          # are given.
          define_method(:"add_#{meth}") do |*args|
            unless args.empty?
              case v = @opts[setting]
              when :all
                # If all domains are already allowed, there is no reason to add more.
                return
              when Array
                @opts[setting] = option_value(v + args)
              else
                @opts[setting] = option_value(args)
              end
            end
            nil
          end

          # get_* method always returns current setting value.
          define_method(:"get_#{meth}") do
            @opts[setting]
          end
        end

        def initialize
          clear
        end

        # Clear all settings, useful to remove any inherited settings.
        def clear
          @opts = {}
          @report_only = nil
          @header_value = nil
        end

        # Do not allow future modifications to any settings.
        def freeze
          @opts.freeze
          header_value.freeze
          super
        end

        # The header name to use, depends on whether report only mode has been enabled.
        def header_key
          @report_only ? RodaResponseHeaders::PERMISSIONS_POLICY_REPORT_ONLY : RodaResponseHeaders::PERMISSIONS_POLICY
        end

        # The header value to use.
        def header_value
          return @header_value if @header_value

          s = String.new
          @opts.each do |k, vs|
            s << k << "="

            if vs == :all
              s << '*, '
            else
              s << '('
              vs.each{|v| append_formatted_value(s, v)}
              s.chop! unless vs.empty?
              s << '), '
            end
          end
          s.chop!
          s.chop!
          @header_value = s
        end

        # Set whether the Permissions-Policy-Report-Only header instead of the
        # default Permissions-Policy header.
        def report_only(report=true)
          @report_only = report
        end

        # Whether this policy uses report only mode.
        def report_only?
          !!@report_only
        end

        # Set the current policy in the headers hash.  If no settings have been made
        # in the policy, does not set a header.
        def set_header(headers)
          return if @opts.empty?
          headers[header_key] ||= header_value
        end

        private

        # Formats nested values, quoting strings and using :self and :src verbatim.
        def append_formatted_value(s, v)
          case v
          when String
            s << v.inspect << ' '
          when :self
            s << 'self '
          when :src
            s << 'src '
          else
            raise RodaError, "unsupported Permissions-Policy item value used: #{v.inspect}"
          end
        end

        # Make object copy use copy of settings, and remove cached header value.
        def initialize_copy(_)
          super
          @opts = @opts.dup
          @header_value = nil
        end

        # The option value to store for the given args.
        def option_value(args)
          if args.length == 1
            case args[0]
            when :all
              :all
            when :none
              EMPTY_ARRAY
            else
              args.freeze
            end
          else
            args.freeze
          end
        end
      end

      # Yield the current Permissions Policy to the block.
      def self.configure(app, opts=OPTS)
        policy = app.opts[:permissions_policy] = if policy = app.opts[:permissions_policy]
          policy.dup
        else
          Policy.new
        end

        if default = opts[:default]
          SUPPORTED_SETTINGS.each do |setting|
            policy.send(setting.tr('-', '_'), *default)
          end
        end

        yield policy if defined?(yield)
        policy.freeze
      end

      module InstanceMethods
        # If a block is given, yield the current permission policy.  Returns the
        # current permissions policy.
        def permissions_policy
          policy = @_response.permissions_policy
          yield policy if defined?(yield)
          policy
        end
      end

      module ResponseMethods
        # Unset any permissions policy when reinitializing
        def initialize
          super
          @permissions_policy &&= nil
        end

        # The current permissions policy to be used for this response.
        def permissions_policy
          @permissions_policy ||= roda_class.opts[:permissions_policy].dup
        end

        # Do not set a permissions policy header for this response.
        def skip_permissions_policy!
          @skip_permissions_policy = true
        end

        private

        # Set the appropriate permissions policy header.
        def set_default_headers
          super
          unless @skip_permissions_policy
            (@permissions_policy || roda_class.opts[:permissions_policy]).set_header(headers)
          end
        end
      end
    end

    register_plugin(:permissions_policy, PermissionsPolicy)
  end
end
