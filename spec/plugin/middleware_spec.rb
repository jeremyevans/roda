require_relative "../spec_helper"

describe "middleware plugin" do 
  [false, true].each do |def_call|
    meth = def_call ? :deprecated : :it
    send meth, "turns Roda app into middlware" do
      a2 = app(:bare) do
        plugin :middleware

        if def_call
          def call
            super
          end
        end

        route do |r|
          r.is "a" do
            "a2"
          end
          r.post "b" do
            "b2"
          end
        end
      end

      a3 = app(:bare) do
        plugin :middleware

        route do |r|
          r.get "a" do
            "a3"
          end
          r.get "b" do
            "b3"
          end
        end
      end

      app(:bare) do
        use a3
        use a2

        route do |r|
          r.is "a" do
            "a1"
          end
          r.is "b" do
            "b1"
          end
        end
      end

      body('/a').must_equal 'a3'
      body('/b').must_equal 'b3'
      body('/a', 'REQUEST_METHOD'=>'POST').must_equal 'a2'
      body('/b', 'REQUEST_METHOD'=>'POST').must_equal 'b2'
      body('/a', 'REQUEST_METHOD'=>'PATCH').must_equal 'a2'
      body('/b', 'REQUEST_METHOD'=>'PATCH').must_equal 'b1'
    end

    send meth, "supports :forward_response_headers middleware option" do
      mid1 = app(:bare) do
        plugin :middleware, :forward_response_headers=>true
        def call; super end if def_call

        route do |r|
          response['a'] = 'A1'
          response['b'] = 'B1'
        end
      end

      mid2 = app(:bare) do
        plugin :middleware
        def call; super end if def_call

        route do |r|
          response['c'] = 'C1'
          response['d'] = 'D1'
        end
      end

      app(:bare) do
        use mid1
        use mid2
        def call; super end if def_call

        route do |r|
          response['a'] = 'A2'
          response['c'] = 'C2'

          r.root do
            'body'
          end
        end
      end

      header('a').must_equal 'A2'
      header('b').must_equal 'B1'
      header('c').must_equal 'C2'
      header('d').must_be_nil
    end
  end

  it "makes it still possible to use the Roda app normally" do
    app(:middleware) do |_|
      "a"
    end
    body.must_equal 'a'
  end

  deprecated "makes it still possible to use the Roda app normally when #call is overwritten" do
    app(:bare) do
      plugin :middleware
      def call
        super
      end

      route do |_|
        "a"
      end
    end
    app
    body.must_equal 'a'
  end

  it "makes middleware always use a subclass of the app" do
    app(:middleware) do |r|
      r.get{opts[:a]}
    end
    app.opts[:a] = 'a'
    a = app
    app(:bare) do
      use a
      route{|_|}
    end
    body.must_equal 'a'
    a.opts[:a] = 'b'
    body.must_equal 'a'
  end

  it "sets temporary name of the subclass" do
    app(:middleware) do |r|
      r.get{self.class.name || "anonymous"}
    end
    a = app
    app(:bare) do
      use a
      route {|_|}
    end
    body.must_include '::middleware_subclass'

    begin
      Object.const_set(:MyApp, a)
      app(:bare) do
        use a
        route {|_|}
      end
      body.must_equal 'MyApp::middleware_subclass'
    ensure
      Object.send(:remove_const, :MyApp)
    end
  end if RUBY_VERSION >= "3.3"

  it "should raise error if attempting to use options for Roda application that does not support configurable middleware" do
    a1 = app(:bare){plugin :middleware}
    proc{app(:bare){use a1, :foo; route{|_|}; build_rack_app}}.must_raise Roda::RodaError
    proc{app(:bare){use(a1){}; route{|_|}; build_rack_app}}.must_raise Roda::RodaError
  end

  it "supports configuring middleware via a block" do
    a1 = app(:bare) do
      plugin :middleware do |mid, *args, &block|
        mid.opts[:a] = args.concat(block.call(:quux)).join(' ')
      end
      opts[:a] = 'a1'

      route do |r|
        r.is 'a' do opts[:a] end
      end
    end

    body('/a').must_equal 'a1'
    
    app(:bare) do
      use a1, :foo, :bar do |baz|
        [baz, :a1]
      end

      route do |_|
        'b1'
      end
    end

    body.must_equal 'b1'
    body('/a').must_equal 'foo bar quux a1'

    @app = a1
    body('/a').must_equal 'a1'
  end

  it "is compatible with the multi_route plugin" do
    app(:bare) do
      plugin :multi_route
      plugin :middleware

      route("a") do |r|
        r.is "b" do
          "ab"
        end
      end

      route do |r|
        r.multi_route
      end
    end

    body('/a/b').must_equal 'ab'
  end

  it "uses the app's middleware if :include_middleware option is given" do
    mid = Struct.new(:app) do
      def call(env)
        env['foo'] = 'bar'
        app.call(env)
      end
    end
    app(:bare) do
      plugin :middleware, :include_middleware=>true
      use mid
      route{|_|}
    end
    mid2 = app
    app(:bare) do
      use mid2
      route{|_| env['foo']}
    end
    body.must_equal 'bar'
  end

  it "calls :handle_result option with env and response" do
    app(:bare) do
      plugin :middleware, :handle_result=>(proc do |env, res|
        res[1].delete(RodaResponseHeaders::CONTENT_LENGTH)
        res[2] << env['foo']
      end)
      route{|_|}
    end
    mid2 = app
    app(:bare) do
      use mid2
      route{|_| env['foo'] = 'bar'; 'baz'}
    end
    body.must_equal 'bazbar'
  end

  it "works with the route_block_args block when loaded before" do
    app(:bare) do
      plugin :middleware
      plugin :route_block_args do
        [request.path, response]
      end

      route do |path, res|
        request.get 'a' do
          res.write(path + '2')
        end
      end
    end
    a = app

    app(:bare) do
      use a
      route{|r| 'b'}
    end

    body('/a').must_equal '/a2'
    body('/x').must_equal 'b'
  end

  it "works with the route_block_args block when loaded after" do
    app(:bare) do
      plugin :route_block_args do
        [request.path, response]
      end
      plugin :middleware

      route do |path, res|
        request.get 'a' do
          res.write(path + '2')
        end
      end
    end
    a = app

    app(:bare) do
      use a
      route{|r| 'b'}
    end

    body('/a').must_equal '/a2'
    body('/x').must_equal 'b'
  end

  it "supports :env_var middleware option" do
    a2 = app(:bare) do
      plugin :middleware, :env_var=>'roda.fn'

      route do |r|
        r.is "a" do
          "a2"
        end
        r.post "b" do
          "b2"
        end
      end
    end

    a3 = app(:bare) do
      plugin :middleware, :env_var=>'roda.fn2'

      route do |r|
        r.get "a" do
          "a3"
        end
        r.get "b" do
          "b3"
        end
      end
    end

    app(:bare) do
      use a3
      use a2

      route do |r|
        r.is "a" do
          "a1"
        end
        r.is "b" do
          "b1"
        end
      end
    end

    body('/a').must_equal 'a3'
    body('/b').must_equal 'b3'
    body('/a', 'REQUEST_METHOD'=>'POST').must_equal 'a2'
    body('/b', 'REQUEST_METHOD'=>'POST').must_equal 'b2'
    body('/a', 'REQUEST_METHOD'=>'PATCH').must_equal 'a2'
    body('/b', 'REQUEST_METHOD'=>'PATCH').must_equal 'b1'
  end

  it "supports :next_if_not_found plugin option" do
    a2 = app(:bare) do
      plugin :middleware, :next_if_not_found=>true

      route do |r|
        r.on "a" do
          r.is "b" do
            'a-b'
          end
        end
      end
    end

    app(:bare) do
      use a2

      route do |r|
        r.on 'a' do
          'a'
        end
        'c'
      end
    end

    body('/a').must_equal 'a'
    body('/a/b').must_equal 'a-b'
    body('/d').must_equal 'c'
  end
end
