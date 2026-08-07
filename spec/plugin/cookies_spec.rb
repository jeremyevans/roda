require_relative "../spec_helper"

describe "cookies plugin" do 
  it "should set cookies on response" do
    app(:cookies) do |r|
      response.set_cookie("foo", "bar")
      response.set_cookie("bar", "baz")
      "Hello"
    end

    ["foo=bar\nbar=baz", %w"foo=bar bar=baz"].must_include header(RodaResponseHeaders::SET_COOKIE)
    body.must_equal 'Hello'
  end

  it "should delete cookies on response" do
    app(:cookies) do |r|
      response.set_cookie("foo", "bar")
      response.delete_cookie("foo")
      "Hello"
    end

    cookie = header(RodaResponseHeaders::SET_COOKIE)
    if Rack.release >= '2.3'
      cookie[0].must_match(/foo=bar/)
      cookie[1].must_match(/foo=; (max-age=0; )?expires=Thu, 01[ -]Jan[ -]1970 00:00:00 (-0000|GMT)/)
    else
      if cookie.is_a?(Array)
        cookie.length.must_equal 1
        cookie = cookie[0]
      end
      cookie.must_match(/foo=; (max-age=0; )?expires=Thu, 01[ -]Jan[ -]1970 00:00:00 (-0000|GMT)/)
    end
    body.must_equal 'Hello'
  end

  it "should pass default cookie options when setting" do
    app.plugin :cookies, :path => '/foo'
    app.route {|_| response.set_cookie("foo", "bar") }
    header(RodaResponseHeaders::SET_COOKIE).must_equal "foo=bar; path=/foo"

    app.route {|_| response.set_cookie("foo", :value=>"bar", :path=>'/baz') }
    header(RodaResponseHeaders::SET_COOKIE).must_equal "foo=bar; path=/baz"
  end

  it "should pass default cookie options when deleting" do
    app.plugin :cookies, :domain => 'example.com'
    app.route {|_| response.delete_cookie("foo") }
    header(RodaResponseHeaders::SET_COOKIE).must_match(/foo=; domain=example.com; (max-age=0; )?expires=Thu, 01[ -]Jan[ -]1970 00:00:00 (-0000|GMT)/)

    app.route {|_| response.delete_cookie("foo", :domain=>'bar.com') }
    header(RodaResponseHeaders::SET_COOKIE).must_match(/foo=; domain=bar.com; (max-age=0; )?expires=Thu, 01[ -]Jan[ -]1970 00:00:00 (-0000|GMT)/)
  end

  it "should not override existing default cookie options" do
    app.plugin :cookies, :path => '/foo'
    app.plugin :cookies
    app.route {|_| response.set_cookie("foo", "bar") }

    header(RodaResponseHeaders::SET_COOKIE).must_equal "foo=bar; path=/foo"
  end
end
