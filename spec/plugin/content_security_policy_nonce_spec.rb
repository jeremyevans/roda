require_relative "../spec_helper"

describe "content_security_policy_nonce plugin" do
  it "generates a single request nonce per request" do
    app(:bare) do
      plugin :content_security_policy_nonce

      route do |r|
        r.get 'js' do
          %(<script nonce="#{r.content_security_policy_nonce}"></script>) +
          %(<script nonce="#{r.content_security_policy_nonce}"></script>)
        end
      end
    end

    _, h, b = req("/js")

    matched = h["Content-Security-Policy"].must_match /script\-src nonce-(\w+)/
    nonce = matched.captures.first
    nonce.size.must_equal 64
    b.must_equal ["<script nonce=\"#{nonce}\"></script>" * 2]
  end

  it "allows overriding the nonce generator" do
    app(:bare) do
      plugin :content_security_policy_nonce do
        "NONCE"
      end

      route do |r|
        r.get 'js' do
          %(<script nonce="#{r.content_security_policy_nonce}"></script>)
        end
      end
    end

    _, h, b = req("/js")

    h["Content-Security-Policy"].must_equal "script-src nonce-NONCE"
    b.must_equal ["<script nonce=\"NONCE\"></script>"]
  end
end
