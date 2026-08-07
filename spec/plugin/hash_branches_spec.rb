require_relative "../spec_helper"

describe "hash_branches plugin" do 
  before do
    app(:bare) do
      plugin :hash_branches

      hash_branch("a") do |r|
        r.is "" do
          "a0"
        end
        
        r.is "a" do
          "a1"
        end

        r.hash_branches

        "a2"
      end

      hash_branch("/a", "b") do |r|
        r.is "" do
          "ab0"
        end
        
        r.is "a" do
          "ab1"
        end

        r.hash_branches

        "ab2"
      end

      hash_branch("", "b") do |r|
        r.is "" do
          "b0"
        end
        
        r.is "a" do
          "b1"
        end

        "b2"
      end

      hash_branch(:p, "x") do |r|
        r.is do
          'px'
        end

        'pnx'
      end

      route do |r|
        r.hash_branches

        r.on 'p' do
          r.hash_branches(:p)
          
          r.hash_branches("")

          "p"
        end

        "n"
      end
    end
  end

  it "adds support for routing via r.hash_branches" do
    body.must_equal 'n'
    body('/a').must_equal 'a2'
    body('/a/').must_equal 'a0'
    body('/a/a').must_equal 'a1'
    body('/a/b').must_equal 'ab2'
    body('/a/b/').must_equal 'ab0'
    body('/a/b/a').must_equal 'ab1'
    body('/b').must_equal 'b2'
    body('/b/').must_equal 'b0'
    body('/b/a').must_equal 'b1'
    body('/p').must_equal 'p'
    body('/p/x').must_equal 'px'
    body('/p/x/1').must_equal 'pnx'

    body('/p/a').must_equal 'a2'
    body('/p/a/').must_equal 'a0'
    body('/p/a/a').must_equal 'a1'
    body('/p/a/b').must_equal 'a2'
    body('/p/a/b/').must_equal 'a2'
    body('/p/a/b/a').must_equal 'a2'
    body('/p/b').must_equal 'b2'
    body('/p/b/').must_equal 'b0'
    body('/p/b/a').must_equal 'b1'
    body('/p/p').must_equal 'p'
    body('/p/p/x').must_equal 'p'
    body('/p/p/x/1').must_equal 'p'
  end

  it "works when freezing the app" do
    app.freeze
    body.must_equal 'n'
    body('/a').must_equal 'a2'
    body('/a/').must_equal 'a0'
    proc{app.hash_branch("foo"){|_|}}.must_raise
  end

  it "allows removing a hash branch" do
    2.times do
      app.hash_branch('a')
      body.must_equal 'n'
      body('/a').must_equal 'n'
      body('/a/').must_equal 'n'
      body('/p/x').must_equal 'px'
    end
  end

  it "works when subclassing the app" do
    old_app = app
    @app = Class.new(app)
    @app.route(&old_app.route_block)
    body.must_equal 'n'
    body('/a').must_equal 'a2'
    body('/a/').must_equal 'a0'
    body('/p/x').must_equal 'px'
  end

  it "handles loading the plugin multiple times correctly" do
    app.plugin :hash_routes
    body.must_equal 'n'
    body('/a').must_equal 'a2'
    body('/a/').must_equal 'a0'
    body('/p/x').must_equal 'px'
  end

  it "r.hash_branch handles loading the same route more than once" do
    app.hash_branch(:p, "x") do |r|
      'px'
    end

    body('/p').must_equal 'p'
    body('/p/x').must_equal 'px'
  end
end
