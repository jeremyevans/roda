# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The content_security_policy_nonce plugin builds on top of the content_security_policy
    # plugin and helps with generating nonces for +script+ and +style+ tags. It is recommended
    # to avoid inline +script+ and +style+ tags, but if you must use them, this allows
    # safe usage via nonces. Enable by loading the plugin:
    #
    #   plugin :content_security_policy_nonce
    #
    # You can then generate nonce values by calling the +content_security_policy_nonce+ method:
    #
    #   r.get 'js' do
    #     "<script nonce=\"#{content_security_policy_nonce}\">alert('inline')</script>"
    #   end
    #
    # This method will return the nonce value to use, as well as allow the nonce for both
    # +script-src+ and +style-src+ in the +Content-Security-Policy+ response header.
    #
    # By default, nonce values are 44-byte random generated URL safe base64 strings. You can
    # override the default nonce generator by passing a block to the plugin:
    #
    #   plugin :content_security_policy_nonce do
    #     # this block must return a string.
    #   end
    #
    # The block is evaluated in route block scope context.
    module ContentSecurityPolicyNonce
      SCOPE_INSTANCE_VARIABLES = [:@content_security_policy_nonce].freeze

      def self.load_dependencies(app, &block)
        app.plugin :content_security_policy
      end

      def self.configure(app, &block)
        if block
          app.class_exec do
            define_method(:content_security_policy_nonce_generator, &block)
            private :content_security_policy_nonce_generator
          end
        end
      end

      module InstanceMethods
        # Return the content security policy nonce value. If one hasn't already
        # been generated, this generates it, and adds to the script-src and style-src
        # in the response's Content-Security-Policy header.
        def content_security_policy_nonce
          unless nonce = @content_security_policy_nonce 
            nonce = @content_security_policy_nonce = content_security_policy_nonce_generator
            a = [:nonce, nonce]
            content_security_policy.add_script_src(a)
            content_security_policy.add_style_src(a)
          end

          nonce
        end

        private

        # Generate a nonce value. This method is overridden if the plugin
        # is passed a block.
        def content_security_policy_nonce_generator
          SecureRandom.urlsafe_base64(33)
        end
      end
    end

    register_plugin(:content_security_policy_nonce, ContentSecurityPolicyNonce)
  end
end
