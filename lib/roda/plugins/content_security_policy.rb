# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The content_security_policy plugin allows you to easily set a Content-Security-Policy
    # header for the application, which modern browsers will use to control access to specific
    # types of page content.
    #
    # You would generally call the plugin with a block to set the default policy:
    #
    #   plugin :content_security_policy do |csp|
    #     csp.default_src :none
    #     csp.img_src :self
    #     csp.style_src :self
    #     csp.script_src :self
    #     csp.font_src :self
    #     csp.form_action :self
    #     csp.base_uri :none
    #     csp.frame_ancestors :none
    #     csp.block_all_mixed_content
    #   end
    #
    # Then, anywhere in the routing tree, you can customize the policy for just that
    # branch or action using the same block syntax:
    #
    #   r.get 'foo' do
    #     content_security_policy do |csp|
    #       csp.object_src :self
    #       csp.add_style_src 'bar.com'
    #     end
    #     # ...
    #   end
    #
    # In addition to using a block, you can also call methods on the object returned
    # by the method:
    #
    #   r.get 'foo' do
    #     content_security_policy.script_src :self, 'example.com', [:nonce, 'foobarbaz']
    #     # ...
    #   end
    #
    # The following methods are available for configuring the content security policy,
    # which specify the setting (substituting _ with -): 
    #
    # * base_uri
    # * child_src
    # * connect_src
    # * default_src
    # * font_src
    # * form_action
    # * frame_ancestors
    # * frame_src
    # * img_src
    # * manifest_src
    # * media_src
    # * object_src
    # * plugin_types
    # * report_to
    # * report_uri
    # * require_sri_for
    # * sandbox
    # * script_src
    # * style_src
    # * worker_src
    #
    # All of these methods support any number of arguments, and each argument should
    # be one of the following types:
    #
    # String :: used verbatim
    # Symbol :: Substitutes +_+ with +-+ and surrounds with <tt>'</tt>
    # Array :: only accepts 2 element arrays, joins elements with +-+ and
    #          surrounds the result with <tt>'</tt>
    #
    # Example:
    #
    #   content_security_policy.script_src :self, :unsafe_eval, 'example.com', [:nonce, 'foobarbaz']
    #   # script-src 'self' 'unsafe-eval' example.com 'nonce-foobarbaz'; 
    #  
    # When calling a method with no arguments, the setting is removed from the policy instead
    # of being left empty, since all of these setting require at least one value.  Likewise,
    # if the policy does not have any settings, the header will not be added.
    #
    # Calling the method overrides any previous setting.  Each of the methods has +add_*+ and
    # +get_*+ methods defined. The +add_*+ method appends to any existing setting, and the +get_*+ method
    # returns the current value for the setting.
    #
    #   content_security_policy.script_src :self, :unsafe_eval
    #   content_security_policy.add_script_src 'example.com', [:nonce, 'foobarbaz']
    #   # script-src 'self' 'unsafe-eval' example.com 'nonce-foobarbaz'; 
    #
    #   content_security_policy.get_script_src
    #   # => [:self, :unsafe_eval, 'example.com', [:nonce, 'foobarbaz']]
    #
    # The clear method can be used to remove all settings from the policy. Empty policies
    # do not set any headers. You can use +response.skip_content_security_policy!+ to skip
    # setting a policy.  This is faster than calling +content_security_policy.clear+, since
    # it does not duplicate the default policy.
    #
    # The following methods to set boolean settings are also defined:
    #
    # * block_all_mixed_content
    # * upgrade_insecure_requests
    #
    # Calling these methods will turn on the related setting.  To turn the setting
    # off again, you can call them with a +false+ argument. There is also a <tt>*?</tt> method
    # for each setting for returning whether the setting is currently enabled.
    #
    # Likewise there is also a +report_only+ method for turning on report only mode (the
    # default is enforcement mode), or turning off report only mode if a false argument
    # is given.  Also, there is a +report_only?+ method for returning whether report only
    # mode is enabled.
    module ContentSecurityPolicy
      RESPONSE_INSTANCE_VARIABLES = [:@content_security_policy, :@skip_content_security_policy].freeze

      # Represents a content security policy.
      class Policy
        '
        base-uri
        child-src
        connect-src
        default-src
        font-src
        form-action
        frame-ancestors
        frame-src
        img-src
        manifest-src
        media-src
        object-src
        plugin-types
        report-to
        report-uri
        require-sri-for
        sandbox
        script-src
        style-src
        worker-src
        '.split.each(&:freeze).each do |setting|
          meth = setting.tr('-', '_').freeze

          # Setting method name sets the setting value, or removes it if no args are given.
          define_method(meth) do |*args|
            if args.empty?
              @opts.delete(setting)
            else
              @opts[setting] = args.freeze
            end
            nil
          end

          # add_* method name adds to the setting value, or clears setting if no values
          # are given.
          define_method("add_#{meth}") do |*args|
            unless args.empty?
              @opts[setting] ||= EMPTY_ARRAY
              @opts[setting] += args
              @opts[setting].freeze
            end
            nil
          end

          # get_* method always returns current setting value.
          define_method("get_#{meth}") do
            @opts[setting]
          end
        end

        %w'block-all-mixed-content upgrade-insecure-requests'.each(&:freeze).each do |setting|
          meth = setting.tr('-', '_').freeze

          # Setting method name turns on setting if true or no argument given,
          # or removes setting if false is given.
          define_method(meth) do |arg=true|
            if arg
              @opts[setting] = true
            else
              @opts.delete(setting)
            end

            nil
          end

          # *? method returns true or false depending on whether setting is enabled.
          define_method("#{meth}?") do
            !!@opts[setting]
          end
        end

        def initialize
          clear
        end

        # Clear all settings, useful to remove any inherited settings.
        def clear
          @opts = {}
        end

        # Do not allow future modifications to any settings.
        def freeze
          @opts.freeze
          header_value.freeze
          super
        end

        # The header name to use, depends on whether report only mode has been enabled.
        def header_key
          @report_only ? RodaResponseHeaders::CONTENT_SECURITY_POLICY_REPORT_ONLY : RodaResponseHeaders::CONTENT_SECURITY_POLICY
        end

        # The header value to use.
        def header_value
          return @header_value if @header_value

          s = String.new
          @opts.each do |k, vs|
            s << k
            unless vs == true
              vs.each{|v| append_formatted_value(s, v)}
            end
            s << '; '
          end
          @header_value = s
        end

        # Set whether the Content-Security-Policy-Report-Only header instead of the
        # default Content-Security-Policy header.
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

        # Handle three types of values when formatting the header:
        # String :: used verbatim
        # Symbol :: Substitutes _ with - and surrounds with '
        # Array :: only accepts 2 element arrays, joins them with - and
        #          surrounds them with '
        def append_formatted_value(s, v)
          case v
          when String
            s << ' ' << v
          when Array
            case v.length
            when 2
              s << " '" << v.join('-') << "'"
            else
              raise RodaError, "unsupported CSP value used: #{v.inspect}"
            end
          when Symbol
            s << " '" << v.to_s.tr('_', '-') << "'"
          else
            raise RodaError, "unsupported CSP value used: #{v.inspect}"
          end
        end

        # Make object copy use copy of settings, and remove cached header value.
        def initialize_copy(_)
          super
          @opts = @opts.dup
          @header_value = nil
        end
      end


      # Yield the current Content Security Policy to the block.
      def self.configure(app)
        policy = app.opts[:content_security_policy] = if policy = app.opts[:content_security_policy]
          policy.dup
        else
          Policy.new
        end

        yield policy if defined?(yield)
        policy.freeze
      end

      module InstanceMethods
        # If a block is given, yield the current content security policy.  Returns the
        # current content security policy.
        def content_security_policy
          policy = @_response.content_security_policy
          yield policy if defined?(yield)
          policy
        end
      end

      module ResponseMethods
        # Unset any content security policy when reinitializing
        def initialize
          super
          @content_security_policy &&= nil
        end

        # The current content security policy to be used for this response.
        def content_security_policy
          @content_security_policy ||= roda_class.opts[:content_security_policy].dup
        end

        # Do not set a content security policy header for this response.
        def skip_content_security_policy!
          @skip_content_security_policy = true
        end

        private

        # Set the appropriate content security policy header.
        def set_default_headers
          super
          unless @skip_content_security_policy
            (@content_security_policy || roda_class.opts[:content_security_policy]).set_header(headers)
          end
        end
      end
    end

    register_plugin(:content_security_policy, ContentSecurityPolicy)
  end
end
