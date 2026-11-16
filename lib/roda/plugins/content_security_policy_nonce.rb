# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The content_security_policy_nonce plugin helps with generating nonces for script tags, which
    # allows them to pass the content security policy check.
    #
    #   plugin :content_security_policy_nonce
    #
    # Then, you can generate nonce like the following:
    #
    #   r.get 'js' do
    #     "<script nonce=\"#{request.content_security_policy_nonce}\">alert('inline')</script>"
    #   end
    #
    # By default, nonces are 64 byte random generated hexa strings. You can apply your own logic
    # to generate nonces with a block:
    #
    #   plugin :content_security_policy_nonce do |re|
    #     # this block must return a string.
    #   end
    #
    module ContentSecurityPolicyNonce

      # Yield the current Content Security Policy to the block.
      def self.configure(app, &block)
        app.opts[:nonce_generator] = block || method(:nonce_generator)
      end

      def self.nonce_generator(_req)
        SecureRandom.hex(32)
      end


      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :nonce_generator)
      end

      module RequestMethods
        # If a block is given, yield the current content security policy.  Returns the
        # current content security policy.
        def content_security_policy_nonce
          @content_security_policy_nonce ||= begin
            nonce = scope.opts[:nonce_generator][self]
            response.headers["content-security-policy"] = "script-src nonce-#{nonce}"
            nonce
          end
        end
      end
    end

    register_plugin(:content_security_policy_nonce, ContentSecurityPolicyNonce)
  end
end
