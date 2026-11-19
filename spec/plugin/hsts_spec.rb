require_relative "../spec_helper"

describe "default_headers plugin" do 
  def app(opts={})
    super(:bare) do
      plugin :hsts, **opts
      route do |r|
        ''
      end
    end
  end

  it "sets appropriate headers for the response" do
    app
    req[1][RodaResponseHeaders::STRICT_TRANSPORT_SECURITY].must_equal "max-age=63072000; includeSubDomains"
  end

  it "supports :preload option" do
    app(preload: true)
    req[1][RodaResponseHeaders::STRICT_TRANSPORT_SECURITY].must_equal "max-age=63072000; includeSubDomains; preload"
  end

  it "supports subdomains: false option" do
    app(subdomains: false)
    req[1][RodaResponseHeaders::STRICT_TRANSPORT_SECURITY].must_equal "max-age=63072000"
  end
end
