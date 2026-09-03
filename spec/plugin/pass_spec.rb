require_relative "../spec_helper"

describe "pass plugin" do 
  it "skips the current block if pass is called" do
    app(:pass) do |r|
      r.root do
        r.pass if env['FOO'] == 'true'
        'root'
      end

      r.on :id do |id|
        r.pass if id == 'foo'
        id
      end

      r.on :x, :y do |x, y|
        x + y
      end
    end

    body.must_equal 'root'
    status('FOO'=>'true').must_equal 404
    body("/a").must_equal 'a'
    body("/a/b").must_equal 'a'
    body("/foo/a").must_equal 'fooa'
    body("/foo/a/b").must_equal 'fooa'
    status("/foo").must_equal 404
  end

  it "works with hash_branches and hash_paths" do
    app(:bare) do
      plugin :pass
      plugin :hash_branches
      plugin :hash_paths

      hash_branch("a", &:pass)
      hash_path("/b", &:pass)

      route do |r|
        r.hash_branches
        r.hash_paths
        r.remaining_path
      end
    end

    body('/b').must_equal '/b'
    body('/a').must_equal '/a'
    body('/a/b').must_equal '/a/b'
  end

  it "works with optimized_segment_matchers and optimized_string_matchers" do
    app(:bare) do
      plugin :pass
      plugin :optimized_segment_matchers
      plugin :optimized_string_matchers
      route do|r|
        res = String.new
        r.is_segment do |s|
          res << 'i' << s << "-"
          r.pass
        end
        r.on_segment do |s|
          res << 'o' << s << "-"
          r.pass
        end
        r.is_exactly('d') do
          res << 'xd'
          r.pass
        end
        r.on_branch('c') do
          res << 'xc'
          r.pass
        end
        res
      end
    end

    body.must_equal ''
    body("/a").must_equal 'ia-oa-'
    body("/a/b").must_equal 'oa-'
    body("/c").must_equal 'ic-oc-xc'
    body("/d").must_equal 'id-od-xd'
  end
end
