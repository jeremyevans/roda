require_relative "../spec_helper"

describe "bearer_token plugin" do 
  it "adds r.bearer_token method for bearer token access" do
    app(:bearer_token) do |r|
      r.bearer_token.to_s
    end

    body.must_equal ''
    body("HTTP_AUTHORIZATION" => "").must_equal ''
    body("HTTP_AUTHORIZATION" => "Foo bar").must_equal ''
    body("HTTP_AUTHORIZATION" => "Bearer: foo").must_equal ''
    body("HTTP_AUTHORIZATION" => "xBearer foo").must_equal ''
    body("HTTP_AUTHORIZATION" => "Bearer foo").must_equal 'foo'
    body("HTTP_AUTHORIZATION" => "bearer foo").must_equal 'foo'
    body("HTTP_AUTHORIZATION" => "BEArer foo").must_equal 'foo'
  end
end
