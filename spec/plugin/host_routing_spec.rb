require_relative "../spec_helper"

describe "host_routing plugin" do 
  it "adds support for routing based on host name" do
    app(:bare) do
      plugin :host_routing do |hosts|
        hosts.to :t1, "t1.Example.com"
        hosts.to :t2, "t2.Example.com", "tx.Example.com"
        hosts.default :t1
      end

      route do |r|
        r.t1 do
          "t1-#{r.t1?}-#{r.t2?}"
        end

        r.t2 do
          "t2-#{r.t1?}-#{r.t2?}"
        end
      end
    end

    2.times do
      body.must_equal 't1-true-false'
      body('HTTP_HOST'=>"t1.example.com").must_equal 't1-true-false'
      body('HTTP_HOST'=>"t2.example.com").must_equal 't2-false-true'
      body('HTTP_HOST'=>"tx.example.com").must_equal 't2-false-true'
      body('HTTP_HOST'=>"T1.example.com").must_equal 't1-true-false'
      body('HTTP_HOST'=>"T2.example.com").must_equal 't2-false-true'
      body('HTTP_HOST'=>"Tx.example.com").must_equal 't2-false-true'
      @app = Class.new(@app)
    end
  end

  it "hosts.default accepts a block evaluated in route block scope" do
    app(:bare) do
      plugin :host_routing do |hosts|
        hosts.register :t2, :t3
        hosts.default :t1 do |host|
          if host.start_with?('t2.example.com')
            :t2
          elsif request.GET['b']
            :t3
          end
        end
      end

      route do |r|
        r.t1 do
          "t1-#{r.t1?}-#{r.t2?}-#{r.t3?}"
        end

        r.t2 do
          "t2-#{r.t1?}-#{r.t2?}-#{r.t3?}"
        end

        r.t3 do
          "t3-#{r.t1?}-#{r.t2?}-#{r.t3?}"
        end
      end
    end

    body.must_equal 't1-true-false-false'
    body('HTTP_HOST'=>"t2.example.com").must_equal 't2-false-true-false'
    body('QUERY_STRING'=>"b=1").must_equal 't3-false-false-true'
    body('SERVER_NAME'=>"t2.example.com").must_equal 't2-false-true-false'
    body('HTTP_X_FORWARDED_HOST'=>"t2.example.com").must_equal 't2-false-true-false'
  end

  it "supports :scope_predicates option for also defining predicates in route block scope" do
    app(:bare) do
      plugin :host_routing, :scope_predicates=>true do |hosts|
        hosts.to :t2, "t2.example.com"
        hosts.default :t1
      end

      route do |r|
        r.t1 do
          "t1-#{t1?}-#{t2?}"
        end

        r.t2 do
          "t2-#{t1?}-#{t2?}"
        end
      end
    end

    body('HTTP_HOST'=>"t2.example.com").must_equal 't2-false-true'
    body('HTTP_HOST'=>"t1.example.com").must_equal 't1-true-false'
  end

  it "uses empty string for missing host" do
    app(:bare) do
      plugin :host_routing, :scope_predicates=>true do |hosts|
        hosts.to :t2, ""
        hosts.default :t1
      end

      route do |r|
        r.t1 do
          "t1-#{r.t1?}-#{r.t2?}"
        end

        r.t2 do
          "t2-#{r.t1?}-#{r.t2?}"
        end
      end
    end

    if Rack.release >= '2.1' && !ENV["LINT"]
      # Old rack versions would return host ":" for no SERVER_NAME and no SERVER_PORT
      # Rack::Lint support in spec/helper forces SERVER_NAME=example.com
      body.must_equal 't2-false-true'
    end
    unless Rack.release =~ /\A2\.2/
      # Rack 2.2 uses ":80" host in this case
      body('SERVER_NAME'=>'', 'SERVER_PORT'=>"80").must_equal 't2-false-true'
    end
    body('HTTP_HOST'=>"t1.example.com").must_equal 't1-true-false'
  end

  it "errors if default host is not provided" do
    proc{app.plugin(:host_routing){}}.must_raise Roda::RodaError
    app.plugin(:host_routing){|x| x.default :x}
  end
end
