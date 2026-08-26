# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    module Base64_
      class << self
        if RUBY_VERSION >= '2.4'
          def decode64(str)
            str.unpack1("m0")
          end
        # simplecov:disable
        else
          def decode64(str)
            str.unpack("m0")[0]
          end
        # simplecov:enable
        end

        def urlsafe_encode64(bin)
          str = [bin].pack("m0")
          str.tr!("+/", "-_")
          str
        end

        def urlsafe_decode64(str)
          decode64(str.tr("-_", "+/"))
        end
      end
    end

    register_plugin(:_base64, Base64_)
  end
end
