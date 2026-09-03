require_relative "spec_helper"

describe "redirects" do
  it "should be immediately processed" do
    app do |r|
      r.root do
        r.redirect "/hello"
        "Foo"
      end

      r.is "about" do
        r.redirect "/hello", 301
        "Foo"
      end

      r.is 'foo' do
        r.get do
          r.redirect
        end

        r.post do
          r.redirect
        end
      end

      r.redirect
    end

    status.must_equal 302
    header(RodaResponseHeaders::LOCATION).must_equal '/hello'
    body.must_equal ''

    status("/about").must_equal 301
    header(RodaResponseHeaders::LOCATION, "/about").must_equal '/hello'
    body("/about").must_equal ''

    status("/foo", 'REQUEST_METHOD'=>'POST').must_equal 302
    header(RodaResponseHeaders::LOCATION, "/foo", 'REQUEST_METHOD'=>'POST').must_equal '/foo'
    body("/foo", 'REQUEST_METHOD'=>'POST').must_equal ''

    proc{req('/foo')}.must_raise(Roda::RodaError)
    proc{req('//foo')}.must_raise(Roda::RodaError)
    status('//foo', 'REQUEST_METHOD'=>'POST').must_equal 302
    header(RodaResponseHeaders::LOCATION, "//foo", 'REQUEST_METHOD'=>'POST').must_equal '/'
  end
end
