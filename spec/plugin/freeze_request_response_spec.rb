require_relative "../spec_helper"

describe "freeze_request_response plugin" do 
  it "freezes RodaRequest and RodaResponse when freezing app" do
    app(:freeze_request_response){|_|}
    app::RodaRequest.frozen?.must_equal false
    app::RodaResponse.frozen?.must_equal false
    app.freeze
    app::RodaRequest.frozen?.must_equal true
    app::RodaResponse.frozen?.must_equal true
  end
end
