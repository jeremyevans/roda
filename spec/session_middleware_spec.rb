require_relative "spec_helper"

require 'roda/session_middleware'

describe "RodaSessionMiddleware" do 
  include CookieJar

  it "operates like a session middleware" do
    sess = nil
    env = nil

    app(:bare) do
      use RodaSessionMiddleware, :secret=>'1'*64

      route do |r|
        r.get('s', String, String){|k, v| v.force_encoding('UTF-8'); session[k.to_sym] = v}
        r.get('g',  String){|k| session[k.to_sym].to_s}
        r.get('c'){|k| session.clear; ''}
        r.get('sh'){|k| env = r.env; sess = session; ''}
        ''
      end
    end

    _, h, b = req('/')
    h[RodaResponseHeaders::SET_COOKIE].must_be_nil
    b.must_equal ['']

    _, h, b = req('/s/foo/bar')
    h[RodaResponseHeaders::SET_COOKIE].must_match(/\Aroda\.session=(.*); path=\/; HttpOnly(; SameSite=Lax)?\z/mi)
    b.must_equal ['bar']
    body('/s/foo/bar').must_equal 'bar'
    body('/g/foo').must_equal 'bar'

    body('/s/foo/baz').must_equal 'baz'
    body('/g/foo').must_equal 'baz'

    body("/s/foo/\u1234".b).must_equal "\u1234"
    body("/g/foo").must_equal "\u1234"

    body("/c").must_equal ""
    body("/g/foo").must_equal ""

    body('/s/foo/bar')
    body("/sh").must_equal ""

    sess.must_be_kind_of RodaSessionMiddleware::SessionHash
    sess.req.must_be_kind_of Roda::RodaRequest
    sess.data.must_be_nil
    sess.options[:secret].must_equal('1'*64)
    sess.inspect.must_include "not yet loaded"
    sess.loaded?.must_equal false

    a = []
    sess.each{|k, v| a << k << v}
    a.must_equal %w'foo bar'
    sess.data.must_equal("foo"=>"bar")
    sess.inspect.must_match(/\A\{"foo" ?=> ?"bar"\}\z/)
    sess.loaded?.must_equal true

    sess[:foo].must_equal "bar"
    sess['foo'].must_equal "bar"

    sess.fetch(:foo).must_equal "bar"
    sess.fetch('foo').must_equal "bar"
    proc{sess.fetch('foo2')}.must_raise KeyError
    sess.fetch(:foo, "baz").must_equal "bar"
    sess.fetch('foo', "baz").must_equal "bar"
    sess.fetch('foo2', "baz").must_equal "baz"

    sess.has_key?(:foo).must_equal true
    sess.has_key?("foo").must_equal true
    sess.has_key?("bar").must_equal false
    sess.key?("foo").must_equal true
    sess.key?("bar").must_equal false
    sess.include?("foo").must_equal true
    sess.include?("bar").must_equal false
    
    sess[:foo2] = "bar2"
    sess['foo2'].must_equal "bar2"
    sess.store('foo3', "bar3").must_equal "bar3"
    sess['foo3'].must_equal "bar3"

    env['roda.session.created_at'] = true
    env['roda.session.updated_at'] = true
    sess.clear.must_equal({})
    sess.data.must_equal({})
    env['roda.session.created_at'].must_be_nil
    env['roda.session.updated_at'].must_be_nil

    sess['a'] = 'b'
    env['roda.session.created_at'] = true
    env['roda.session.updated_at'] = true
    sess.destroy.must_equal({})
    sess.data.must_equal({})
    env['roda.session.created_at'].must_be_nil
    env['roda.session.updated_at'].must_be_nil

    sess[:foo] = "bar"
    sess.to_hash.must_equal("foo"=>"bar")
    sess.to_hash.wont_be_same_as(sess.data)

    sess.update("foo2"=>"bar2", :foo=>"bar3").must_equal("foo"=>"bar3", "foo2"=>"bar2")
    sess.data.must_equal("foo"=>"bar3", "foo2"=>"bar2")
    sess.merge!("foo2"=>"bar4").must_equal("foo"=>"bar3", "foo2"=>"bar4")

    sess.replace("foo2"=>"bar5", :foo3=>"bar").must_equal("foo3"=>"bar", "foo2"=>"bar5")
    sess.data.must_equal("foo3"=>"bar", "foo2"=>"bar5")

    sess.delete(:foo3).must_equal("bar")
    sess.data.must_equal("foo2"=>"bar5")
    sess.delete("foo2").must_equal("bar5")
    sess.data.must_equal({})

    sess.exists?.must_equal true
    env.delete('roda.session.serialized')
    sess.exists?.must_equal false

    sess.empty?.must_equal true
    sess[:foo] = "bar"
    sess.empty?.must_equal false
    sess.keys.must_equal ["foo"]
    sess.values.must_equal ["bar"]
  end
end
