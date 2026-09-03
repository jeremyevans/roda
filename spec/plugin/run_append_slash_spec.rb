require_relative "../spec_helper"

describe "run_append_slash plugin" do
  before do
    sub2 = app do |r|
      r.root do
        'sub-bar-root'
      end

      r.get 'baz' do
        'sub-bar-baz'
      end
    end

    sub1 = app(:run_append_slash) do |r|
      r.root do
        'sub-root'
      end

      r.get 'foo' do
        'sub-foo'
      end

      r.on 'bar' do
        r.run sub2
      end
    end

    app(:bare) do
      route do |r|
        r.root do
          'root'
        end

        r.on 'sub' do
          r.run sub1
        end

        r.on '/a' do
          r.run sub1
        end
      end
    end
  end

  it "without plugin does not append a missing trailing slash to #run sub apps" do
    body.must_equal 'root'
    status('/sub').must_equal 404
    body('/sub/').must_equal 'sub-root'
    body('/sub/foo').must_equal 'sub-foo'
    status('/sub/foo/').must_equal 404
    body('/sub/bar/').must_equal 'sub-bar-root'
    body('/sub/bar/baz').must_equal 'sub-bar-baz'
    status('/sub/bar/baz/').must_equal 404
    body('//a/').must_equal 'sub-root'
  end unless ENV['LINT']

  it "internally appends a missing trailing slash to #run sub apps" do
    app.plugin :run_append_slash
    body('/sub').must_equal 'sub-root'
    body('/sub/').must_equal 'sub-root'
    body('/sub/foo').must_equal 'sub-foo'
    status('/sub/foo/').must_equal 404
    body('/sub/bar').must_equal 'sub-bar-root'
    body('/sub/bar/').must_equal 'sub-bar-root'
    body('/sub/bar/baz').must_equal 'sub-bar-baz'
    status('/sub/bar/baz/').must_equal 404
    body('//a').must_equal 'sub-root'
  end

  it "redirects #run sub apps when trailing slash is missing" do
    app.plugin :run_append_slash, :use_redirects => true
    status('/sub').must_equal 302
    header(RodaResponseHeaders::LOCATION, '/sub').must_equal '/sub/'
    body('/sub/').must_equal 'sub-root'
    body('/sub/foo').must_equal 'sub-foo'
    status('/sub/foo/').must_equal 404
    body('/sub/bar').must_equal 'sub-bar-root'
    body('/sub/bar/').must_equal 'sub-bar-root'
    body('/sub/bar/baz').must_equal 'sub-bar-baz'
    status('/sub/bar/baz/').must_equal 404
    body('//a').must_equal 'sub-root'
  end

  it "works with run_handler plugin" do
    sub = app(:bare) { }

    app(:bare) do
      plugin :run_handler
      plugin :run_append_slash

      route do |r|
        r.run sub, not_found: :pass

        r.root do
          "main"
        end
      end
    end

    body("/").must_equal 'main'
  end
end
