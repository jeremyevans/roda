require_relative "../spec_helper"

describe "status_handler plugin" do
  it "executes on no arguments" do
    app(:bare) do
      plugin :status_handler

      status_handler(404) do
        "not found"
      end

      route do |r|
        r.on "a" do
          "found"
        end
      end
    end

    body.must_equal 'not found'
    status.must_equal 404
    body("/a").must_equal 'found'
    status("/a").must_equal 200
  end

  it "passes request if block accepts argument" do
    app(:bare) do
      plugin :status_handler

      status_handler(404) do |r|
        r.path + 'foo'
      end

      route do |r|
      end
    end

    body('/').must_equal '/foo'
    body("/a").must_equal '/afoo'
    status("/").must_equal 404
  end

  it "allows overriding status inside status_handler" do
    app(:bare) do
      plugin :status_handler

      status_handler(404) do
        response.status = 403
        "not found"
      end

      route do |r|
      end
    end

    status.must_equal 403
  end

  it "calculates correct Content-Length" do
    app(:bare) do
      plugin :status_handler

      status_handler(404) do
        "a"
      end

      route{|_|}
    end

    header(RodaResponseHeaders::CONTENT_LENGTH).must_equal "1"
  end

  it "clears existing headers" do
    app(:bare) do
      plugin :status_handler

      status_handler(404) do
        "a"
      end

      route do |r|
        response[RodaResponseHeaders::CONTENT_TYPE] = 'text/pdf'
        response['foo'] = 'bar'
        nil
      end
    end

    header(RodaResponseHeaders::CONTENT_TYPE).must_equal 'text/html'
    header('foo').must_be_nil
  end

  it "keeps specific existing headers if :keep_headers option is used with an array value" do
    app(:bare) do
      plugin :status_handler

      status_handler(404, :keep_headers=>['foo']) do
        "a"
      end

      route do |r|
        response[RodaResponseHeaders::CONTENT_TYPE] = 'text/pdf'
        response['foo'] = 'bar'
        nil
      end
    end

    header(RodaResponseHeaders::CONTENT_LENGTH).must_equal '1'
    header(RodaResponseHeaders::CONTENT_TYPE).must_equal 'text/html'
    header('foo').must_equal 'bar'
  end

  it "raises for invalid :keep_headers option" do
    app(:bare) do
      plugin :status_handler
      proc{status_handler(404, :keep_headers=>true){}}.must_raise Roda::RodaError
    end
  end

  it "does not modify behavior if status_handler is not called" do
    app(:status_handler) do |r|
      r.on "a" do
        "found"
      end
    end

    body.must_equal ''
    body("/a").must_equal 'found'
  end

  it "does not modify behavior if body is not an array" do
    app(:bare) do
      plugin :status_handler

      status_handler(404) do
        "not found"
      end

      o = Object.new
      def o.each(&_); end
      route do |r|
        r.halt [404, {}, o]
      end
    end

    body.must_equal ''
  end

  it "does not modify behavior if body is not an empty array" do
    app(:bare) do
      plugin :status_handler

      status_handler(404) do
        "not found"
      end

      route do |r|
        response.status = 404
        response.write 'a'
      end
    end

    body.must_equal 'a'
  end

  it "does not allow further status handlers to be added after freezing" do
    app(:bare) do
      plugin :status_handler

      status_handler(404) do
        "not found"
      end

      route{|_|}
    end

    app.freeze

    body.must_equal 'not found'
    status.must_equal 404

    proc{app.status_handler(404) { "blah" }}.must_raise

    body.must_equal 'not found'
  end

end
