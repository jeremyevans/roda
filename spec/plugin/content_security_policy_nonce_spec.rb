require_relative "../spec_helper"

describe "content_security_policy_nonce plugin" do
  it "generates a single request nonce per request" do
    nonce = nil
    app(:content_security_policy_nonce) do |r|
      r.get 'js' do
        %(<script nonce="#{nonce = content_security_policy_nonce}"></script>) +
        %(<script nonce="#{content_security_policy_nonce}"></script>)
      end
    end

    _, h, b = req("/js")

    h[RodaResponseHeaders::CONTENT_SECURITY_POLICY].must_equal "script-src 'nonce-#{nonce}'; style-src 'nonce-#{nonce}'; "
    nonce.size.must_equal 44
    b.must_equal ["<script nonce=\"#{nonce}\"></script>" * 2]
  end

  it "works with existing content_security_policy settings" do
    nonce = nil
    app(:content_security_policy_nonce) do |r|
      r.get 'js' do
        content_security_policy.script_src "foo.example.com"
        %(<script nonce="#{nonce = content_security_policy_nonce}"></script>) +
        %(<script nonce="#{content_security_policy_nonce}"></script>)
      end
    end

    _, h, b = req("/js")

    h[RodaResponseHeaders::CONTENT_SECURITY_POLICY].must_equal "script-src foo.example.com 'nonce-#{nonce}'; style-src 'nonce-#{nonce}'; "
    nonce.size.must_equal 44
    b.must_equal ["<script nonce=\"#{nonce}\"></script>" * 2]
  end

  it "allows overriding the nonce generator" do
    app(:bare) do
      plugin :content_security_policy_nonce do
        "NONCE"
      end

      route do |r|
        r.get 'js' do
          %(<script nonce="#{content_security_policy_nonce}"></script>)
        end
      end
    end

    _, h, b = req("/js")

    h[RodaResponseHeaders::CONTENT_SECURITY_POLICY].must_equal "script-src 'nonce-NONCE'; style-src 'nonce-NONCE'; "
    b.must_equal ["<script nonce=\"NONCE\"></script>"]
  end
end
