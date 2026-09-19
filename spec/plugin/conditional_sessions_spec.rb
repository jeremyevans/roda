require_relative "../spec_helper"

describe "conditional_sessions plugin" do 
  include CookieJar

  before do
    allow = @allow = String.new('f')
    app(:bare) do
      plugin :conditional_sessions, :secret=>'1'*64 do
        allow != 'f'
      end

      route do |r|
        r.get('s', String, String){|k, v| v.force_encoding('UTF-8'); session[k] = v}
        r.get('g',  String){|k| session[k].to_s}
        r.get('cat'){r.session_created_at.to_i.to_s}
        r.get('uat'){r.session_updated_at.to_i.to_s}
        r.get('cs'){clear_session.to_s}
        r.get('ps', String, String){|k, v| r.persist_session(response.headers, k => v); env.delete("rack.session"); nil}
        ''
      end
    end
  end

  it "allows sessions if allowed" do
    @allow.replace('t')
    body('/s/foo/bar').must_equal 'bar'
    body('/g/foo').must_equal 'bar'
    body('/cat').to_i.must_be(:>=, Time.now.to_i - 1)
    body('/uat').to_i.must_be(:>=, Time.now.to_i - 1)

    body('/s/foo/baz').must_equal 'baz'
    body('/g/foo').must_equal 'baz'

    body('/ps/foo/quux').must_equal ''
    body('/g/foo').must_equal 'quux'

    body('/cs').must_equal ''
    body('/g/foo').must_equal ''
  end

  it "raises on session if sessions not allowed" do
    proc{body('/s/foo/bar')}.must_raise Roda::RodaError
  end

  it "raises on session_created_at if sessions not allowed" do
    proc{body('/cat')}.must_raise Roda::RodaError
  end

  it "raises on session_updated_at if sessions not allowed" do
    proc{body('/uat')}.must_raise Roda::RodaError
  end

  it "has clear_session do nothing if sessions are not alowed" do
    @allow.replace('t')
    body('/s/foo/bar').must_equal 'bar'
    @allow.replace('f')
    body('/cs').must_equal ''
    @allow.replace('t')
    body('/g/foo').must_equal 'bar'
  end

  it "has persist_session do nothing if sessions are not alowed" do
    @allow.replace('t')
    body('/s/foo/bar').must_equal 'bar'
    @allow.replace('f')
    body('/ps/foo/quux').must_equal ''
    @allow.replace('t')
    body('/g/foo').must_equal 'bar'
  end
end
