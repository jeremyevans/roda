require_relative "../spec_helper"

describe "break plugin" do 
  it "skips the current block if break is called" do
    app(:break) do |r|
      r.root do
        break if env['FOO'] == 'true'
        'root'
      end

      r.on :id do |id|
        break if id == 'foo'
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

  it "works with optimized_segment_matchers and optimized_string_matchers" do
    app(:bare) do
      plugin :break
      plugin :optimized_segment_matchers
      plugin :optimized_string_matchers
      route do|r|
        res = String.new
        r.is_segment do |s|
          res << 'i' << s << "-"
          break
        end
        r.on_segment do |s|
          res << 'o' << s << "-"
          break
        end
        r.is_exactly('d') do
          res << 'xd'
          break
        end
        r.on_branch('c') do
          res << 'xc'
          break
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
