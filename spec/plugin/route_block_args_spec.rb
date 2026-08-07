require_relative "../spec_helper"

describe "route_block_args plugin" do
  it "works with hooks when loaded last" do
    a = []
    app(:bare) do
      plugin :hooks
      before { a << 1 }
      after {|_| a << 2 }
      plugin :route_block_args do
        [request, response]
      end
      route do |req, res|
        response.status = 401
        a << req.path << res.status
        "1"
      end
    end
    body.must_equal "1"
    a.must_equal [1, '/', 401, 2]
  end

  it "works with hooks when loaded first" do
    a = []
    app(:bare) do
      plugin :route_block_args do
        [request, response]
      end
      plugin :hooks
      before { a << 1 }
      after {|_| a << 2 }
      route do |req, res|
        response.status = 401
        a << req.path << res.status
        "1"
      end
    end
    body.must_equal "1"
    a.must_equal [1, '/', 401, 2]
  end

  it "still supports a single route block argument" do
    app(:bare) do
      plugin :route_block_args do
        request
      end
      route { |r| "OK" }
    end

    status('/').must_equal(200)
  end

  it "supports many route block arguments" do
    app(:bare) do
      plugin :route_block_args do
        [request.params, request.env, response.headers]
      end
      route do |p, e, h|
        h['foo'] = "#{p['a']}-#{e['B']}"
      end
    end

    header('foo', 'rack.input'=>rack_input).must_equal('-')
    body('rack.input'=>rack_input).must_equal('-')
    header('foo', 'QUERY_STRING'=>'a=c', 'B'=>'D', 'rack.input'=>rack_input).must_equal('c-D')
  end

  it "works if given after the route block" do
    app(:bare) do
      opts[:check_arity] = false
      route do |p, e, h|
        h['foo'] = "#{p['a']}-#{e['B']}"
      end
      plugin :route_block_args do
        [request.params, request.env, response.headers]
      end
    end

    header('foo', 'rack.input'=>rack_input).must_equal('-')
    body('rack.input'=>rack_input).must_equal('-')
    header('foo', 'QUERY_STRING'=>'a=c', 'B'=>'D', 'rack.input'=>rack_input).must_equal('c-D')
  end
end
