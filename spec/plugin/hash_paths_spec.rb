require_relative "../spec_helper"

describe "hash_paths plugin" do 
  before do
    app(:bare) do
      plugin :hash_paths

      hash_path("/a") do |r|
        r.get{"a"}
        r.post{"ap"}
      end

      hash_path("", "/b") do |_|
        "b"
      end

      hash_path("/c", "/b") do |_|
        "cb"
      end

      hash_path(:p, "/x") do |_|
        'px'
      end

      route do |r|
        r.hash_paths

        r.on 'p' do
          r.hash_paths(:p)
          
          r.hash_paths("")

          "p"
        end

        r.on "c" do
          r.hash_paths

          "c"
        end

        "n"
      end
    end
  end

  it "adds support for routing via r.hash_paths" do
    body.must_equal 'n'
    body('/a').must_equal 'a'
    body('/a', 'REQUEST_METHOD'=>'POST').must_equal 'ap'
    body('/a/').must_equal 'n'
    body('/b').must_equal 'b'
    body('/b/').must_equal 'n'
    body('/c').must_equal 'c'
    body('/c/').must_equal 'c'
    body('/c/b').must_equal 'cb'
    body('/c/b/').must_equal 'c'
    body('/p').must_equal 'p'
    body('/p/x').must_equal 'px'
    body('/p/x/1').must_equal 'p'
  end

  it "works when freezing the app" do
    app.freeze
    body.must_equal 'n'
    body('/a').must_equal 'a'
    body('/a/').must_equal 'n'
    body('/p/x').must_equal 'px'
    proc{app.hash_path("foo"){|_|}}.must_raise
  end

  it "works when subclassing the app" do
    old_app = app
    @app = Class.new(app)
    @app.route(&old_app.route_block)
    body.must_equal 'n'
    body('/a').must_equal 'a'
    body('/a/').must_equal 'n'
    body('/p/x').must_equal 'px'
  end

  it "allows removing a hash path" do
    2.times do
      app.hash_path('/a')
      body.must_equal 'n'
      body('/a').must_equal 'n'
      body('/a/').must_equal 'n'
      body('/p/x').must_equal 'px'
    end
  end

  it "handles loading the plugin multiple times correctly" do
    app.plugin :hash_routes
    body.must_equal 'n'
    body('/a').must_equal 'a'
    body('/a/').must_equal 'n'
    body('/p/x').must_equal 'px'
  end

  it "r.hash_path handles loading the same route more than once" do
    app.hash_path(:p, "x") do |r|
      'px'
    end

    body('/p').must_equal 'p'
    body('/p/x').must_equal 'px'
  end
end
