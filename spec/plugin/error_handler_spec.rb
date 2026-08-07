require_relative "../spec_helper"

describe "error_handler plugin" do 
  it "executes only if error raised" do
    app(:bare) do
      plugin :error_handler

      error do |e|
        e.message
      end

      route do |r|
        r.on "a" do
          "found"
        end

        raise ArgumentError, "bad idea"
      end
    end

    body("/a").must_equal 'found'
    status("/a").must_equal 200
    body.must_equal 'bad idea'
    status.must_equal 500
  end

  deprecated "works if #call is overridden" do
    app(:bare) do
      plugin :error_handler

      def call
        super
      end

      error do |e|
        e.message
      end

      route do |r|
        r.on "a" do
          "found"
        end

        raise ArgumentError, "bad idea"
      end
    end

    body("/a").must_equal 'found'
    status("/a").must_equal 200
    body.must_equal 'bad idea'
    status.must_equal 500
  end

  it "executes on SyntaxError exceptions" do
    app(:bare) do
      plugin :error_handler

      error do |e|
        e.message
      end

      route do |r|
        r.on "a" do
          "found"
        end

        raise SyntaxError, 'bad idea'
      end
    end

    body("/a").must_equal 'found'
    status("/a").must_equal 200
    body.must_equal 'bad idea'
    status.must_equal 500
  end

  it "executes on custom exception classes" do
    app(:bare) do
      plugin :error_handler, :classes=>[StandardError]

      error do |e|
        e.message
      end

      route do |r|
        r.on "a" do
          raise 'foo'
        end

        raise SyntaxError, 'bad idea'
      end
    end

    proc{body}.must_raise SyntaxError
    body("/a").must_equal 'foo'

    @app = Class.new(@app)
    proc{body}.must_raise SyntaxError
    body("/a").must_equal 'foo'
  end

  it "can override status inside error block" do
    app(:bare) do
      plugin :error_handler do |e|
        response.status = 501
        e.message
      end

      route do |r|
        raise ArgumentError, "bad idea"
      end
    end

    status.must_equal 501
  end

  it "calculates correct Content-Length" do
    app(:bare) do
      plugin :error_handler do |e|
        "a"
      end

      route do |r|
        raise ArgumentError, "bad idea"
      end
    end

    header(RodaResponseHeaders::CONTENT_LENGTH).must_equal "1"
  end

  it "clears existing headers" do
    app(:bare) do
      plugin :error_handler do |e|
        "a"
      end

      route do |r|
        response[RodaResponseHeaders::CONTENT_TYPE] = 'text/pdf'
        response['foo'] = 'bar'
        raise ArgumentError, "bad idea"
      end
    end

    header(RodaResponseHeaders::CONTENT_TYPE).must_equal 'text/html'
    header('foo').must_be_nil
  end

  it "can set error via the plugin block" do
    app(:bare) do
      plugin :error_handler do |e|
        e.message
      end

      route do |r|
        raise ArgumentError, "bad idea"
      end
    end

    body.must_equal 'bad idea'
  end

  it "has default error handler also raise" do
    app(:bare) do
      plugin :error_handler

      route do |r|
        raise ArgumentError, "bad idea"
      end
    end

    proc{req}.must_raise(ArgumentError)
  end

  it "logs exceptions during after processing of error handler" do
    app(:bare) do
      plugin :error_handler do |e|
        e.message * 2
      end
      plugin :hooks

      after do |_|
        raise "foo"
      end

      route do |r|
        ''
      end
    end

    errors = rack_input
    body('rack.errors'=>errors).must_equal 'foofoo'
    errors.rewind
    errors.read.split("\n").first.must_equal "Error in after hook processing of error handler: RuntimeError: foo"
  end

  it "has access to current remaining_path" do
    app(:bare) do
      plugin :error_handler do |e|
        request.remaining_path
      end

      route do |r|
        r.on('a') do
          raise ArgumentError, "bad idea"
        end

        raise ArgumentError, "bad idea"
      end
    end

    body.must_equal '/'
    body('/b').must_equal '/b'
    body('/a').must_equal ''
    body('/a/c').must_equal '/c'
  end
end
