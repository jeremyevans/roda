require_relative "../spec_helper"

describe "ip_from_header plugin" do 
  it "returns value in header if present, and default behavior otherwise" do
    app(:bare) do
      plugin :ip_from_header, "x-y"
      route(&:ip)
    end
    body("REMOTE_ADDR"=>"127.0.0.1").must_equal '127.0.0.1'
    body("REMOTE_ADDR"=>"127.0.0.1", "HTTP_X_Y"=>"1.2.3.4").must_equal '1.2.3.4'
  end
end
