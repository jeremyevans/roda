require_relative "../spec_helper"

describe "hash_routes plugin - hash_routes DSL" do 
  before do
    app(:bare) do
      plugin :hash_routes

      hash_routes "" do
        on "a" do |r|
          r.is "" do
            "a0"
          end
          
          r.is "a" do
            "a1"
          end

          r.hash_branches

          "a2"
        end

        on "b" do |r|
          r.is "" do
            "b0"
          end
          
          r.is "a" do
            "b1"
          end

          "b2"
        end

        is "c" do |r|
          "c#{r.request_method}"
        end

        get 'd' do
          'dg'
        end

        post 'e' do
          'ep'
        end
      end

      hash_routes "/a" do |hr|
        hr.dispatch_from(:p, "r")

        hr.dispatch_from(:p, "s") do |r|
          r.is "a" do
            "psa1"
          end
        end

        hr.on "b" do |r|
          r.is "" do
            "ab0"
          end
          
          r.is "a" do
            "ab1"
          end

          r.hash_branches

          "ab2"
        end
      end

      phr = hash_routes(:p)

      phr.is true do |_|
        "pi"
      end

      phr.on "x" do |r|
        r.is do
          'px'
        end

        'pnx'
      end

      route do |r|
        r.hash_routes

        r.on 'p' do
          r.hash_routes(:p)
          
          r.hash_routes("")

          "p"
        end

        "n"
      end
    end
  end

  it "adds support for routing via r.hash_routes" do
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
    body('/c').must_equal 'cGET'
    body('/c', 'REQUEST_METHOD'=>'POST').must_equal 'cPOST'
    body('/c/').must_equal 'n'
    body('/d').must_equal 'dg'
    body('/d', 'REQUEST_METHOD'=>'POST').must_equal ''
    body('/d/').must_equal 'n'
    body('/e').must_equal ''
    body('/e', 'REQUEST_METHOD'=>'POST').must_equal 'ep'
    body('/e/').must_equal 'n'
    body('/p').must_equal 'pi'
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
    body('/p/c').must_equal 'cGET'
    body('/p/c', 'REQUEST_METHOD'=>'POST').must_equal 'cPOST'
    body('/p/c/').must_equal 'p'
    body('/p/d').must_equal 'dg'
    body('/p/d', 'REQUEST_METHOD'=>'POST').must_equal ''
    body('/p/d/').must_equal 'p'
    body('/p/e').must_equal ''
    body('/p/e', 'REQUEST_METHOD'=>'POST').must_equal 'ep'
    body('/p/e/').must_equal 'p'
    body('/p/p').must_equal 'p'
    body('/p/p/x').must_equal 'p'
    body('/p/p/x/1').must_equal 'p'

    body('/p/r/b').must_equal 'ab2'
    body('/p/r/b/').must_equal 'ab0'
    body('/p/r/b/a').must_equal 'ab1'

    body('/p/s/a').must_equal 'psa1'
    body('/p/s/b').must_equal 'ab2'
    body('/p/s/b/').must_equal 'ab0'
    body('/p/s/b/a').must_equal 'ab1'
  end

  it "works when freezing the app" do
    app.freeze
    body.must_equal 'n'
    body('/a').must_equal 'a2'
    body('/a/').must_equal 'a0'
    proc{app.hash_branch("foo"){|_|}}.must_raise
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

  it "r.hash_routes with verb handles loading the same route more than once" do
    app.hash_routes "" do
      get 'd' do
        'dg'
      end
    end

    body('/d').must_equal 'dg'
    body('/d', 'REQUEST_METHOD'=>'POST').must_equal ''
    body('/d/').must_equal 'n'
  end

  it "r.hash_routes with verb handles true" do
    app.hash_routes "" do
      get true do
        'dg'
      end
    end

    unless_lint do
      body('').must_equal 'dg'
      body('', 'REQUEST_METHOD'=>'POST').must_equal ''
    end
    body('/').must_equal 'n'
  end
end

describe "hash_routes plugin" do 
  it "should work with route_block_args" do
    app(:bare) do
      plugin :hash_routes
      plugin :route_block_args do
        [request, response]
      end

      hash_branch 'a' do |r, res|
        r.hash_paths

        res.write('a')
      end

      hash_path '/a', '/b' do |r, res|
        res.write('b')
      end

      route do |r, res|
        r.hash_branches

        'n'
      end
    end

    body.must_equal 'n'
    body('/a').must_equal 'a'
    body('/a/').must_equal 'a'
    body('/a/b').must_equal 'b'
    body('/a/b/').must_equal 'a'
  end

  it "should have r.hash_routes dispatch to both hash_paths and hash_branches with route_block_args" do
    app(:bare) do
      plugin :hash_routes
      plugin :route_block_args do
        [request, response]
      end

      hash_branch 'a' do |r, _|
        r.root do
          'ar'
        end

        'ab'
      end

      hash_path '/a' do |_, _|
        'ap'
      end

      hash_branch 'b' do |_, _|
        'b'
      end

      hash_path '/c' do |_, _|
        'c'
      end

      route do |r, _|
        r.hash_routes

        'n'
      end
    end

    body.must_equal 'n'
    body('/a').must_equal 'ap'
    body('/a/').must_equal 'ar'
    body('/a/b').must_equal 'ab'
    body('/a').must_equal 'ap'
    body('/b').must_equal 'b'
    body('/b/').must_equal 'b'
    body('/c').must_equal 'c'
    body('/c/').must_equal 'n'
  end
end

begin
  require 'tilt/erb'
rescue LoadError
  warn "tilt not installed, skipping hash_routes plugin views test"  
else
describe "hash routes plugin" do 
  it "supports easy rendering of multiple views by name" do
    app(:bare) do
      plugin :render, :views=>'spec/views', :layout=>'layout-yield'
      plugin :hash_routes

      hash_routes '/d' do
        view true, 'a'
        view '', 'b'
        views %w'c'
      end

      route do |r|
        r.on 'd' do
          r.hash_routes
        end
      end
    end

    body('/d').gsub(/\s+/, '').must_equal "HeaderaFooter"
    body('/d/').gsub(/\s+/, '').must_equal "HeaderbFooter"
    body('/d/c').gsub(/\s+/, '').must_equal "HeadercFooter"
  end
end
end
