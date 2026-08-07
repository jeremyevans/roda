require_relative "../spec_helper"

describe "link_to plugin" do 
  it "support string values" do
    app(:bare) do
      plugin :link_to
      route{|r| link_to('a', '/b')}
    end
    body.must_equal '<a href="/b">a</a>'
  end

  it "support symbol values for named paths" do
    app(:bare) do
      plugin :link_to
      path :b, '/bar'
      route{|r| link_to('a', :b)}
    end
    body.must_equal '<a href="/bar">a</a>'
  end

  it "support instances for class paths" do
    c = Class.new
    app(:bare) do
      plugin :link_to
      path c do |_| '/bar' end
      route{|r| link_to('a', c.new)}
    end
    body.must_equal '<a href="/bar">a</a>'
  end

  it "supports nil text values to use the same as the link" do
    app(:bare) do
      plugin :link_to
      route{|r| link_to(nil, '/b')}
    end
    body.must_equal '<a href="/b">/b</a>'
  end

  it "escapes paths but not body" do
    app(:bare) do
      plugin :link_to
      route{|r| link_to('<span>x</span>', '/foo?bar=baz&q=1')}
    end
    body.must_equal '<a href="/foo?bar=baz&amp;q=1"><span>x</span></a>'
  end

  it "supports HTML options" do
    app(:bare) do
      plugin :link_to
      route{|r| link_to('a', '/b', 'foo'=>'"bar"', :baz=>1)}
    end
    body.must_equal '<a href="/b" foo="&quot;bar&quot;" baz="1">a</a>'
  end
end
