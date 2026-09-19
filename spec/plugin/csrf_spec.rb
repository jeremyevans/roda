require_relative "../spec_helper"

begin
  require 'rack/csrf'
rescue LoadError
  warn "rack_csrf not installed, skipping csrf plugin test"  
else
  begin
    require 'rack/csrf/version'
  rescue LoadError
  end

describe "csrf plugin" do 
  include CookieJar

  it "adds csrf protection and csrf helper methods" do
    app(:bare) do
      use(*DEFAULT_SESSION_MIDDLEWARE_ARGS)
      plugin :csrf, :skip=>['POST:/foo']

      route do |r|
        r.get do
          response['tag'] = csrf_tag
          response['metatag'] = csrf_metatag
          response['token'] = csrf_token
          response['field'] = csrf_field
          response['header'] = csrf_header
          'g'
        end
        r.post 'foo' do
          'bar'
        end
        r.post do
          'p'
        end
      end
    end

    io = rack_input
    status('REQUEST_METHOD'=>'POST', 'rack.input'=>io).must_equal 403
    body('/foo', 'REQUEST_METHOD'=>'POST', 'rack.input'=>io).must_equal 'bar'

    s, h, b = req
    s.must_equal 200
    field = h['field']
    token = Regexp.escape(h['token'])
    h['tag'].must_match(/\A<input type="hidden" name="#{field}" value="#{token}" \/>\z/)
    h['metatag'].must_match(/\A<meta name="#{field}" content="#{token}" \/>\z/)
    b.must_equal ['g']
    s, _, b = req('REQUEST_METHOD'=>'POST', 'rack.input'=>io, "HTTP_#{h['header']}"=>h['token'])
    s.must_equal 200
    b.must_equal ['p']

    app.plugin :csrf
    body('/foo', 'REQUEST_METHOD'=>'POST', 'rack.input'=>io).must_equal 'bar'
  end

  it "can optionally skip setting up the middleware" do
    sub_app = Class.new(Roda)
    sub_app.class_exec do
      plugin :csrf, :skip_middleware=>true

      route do |r|
        r.get do
          response['tag'] = csrf_tag
          response['metatag'] = csrf_metatag
          response['token'] = csrf_token
          response['field'] = csrf_field
          response['header'] = csrf_header
          'g'
        end
        r.post 'bar' do
          'foobar'
        end
        r.post do
          'p'
        end
      end
    end

    app(:bare) do
      use(*DEFAULT_SESSION_MIDDLEWARE_ARGS)
      plugin :csrf, :skip=>['POST:/foo/bar']

      route do |r|
        r.on 'foo' do
          r.run sub_app
        end
      end
    end

    io = rack_input
    status('/foo', 'REQUEST_METHOD'=>'POST', 'rack.input'=>io).must_equal 403
    body('/foo/bar', 'REQUEST_METHOD'=>'POST', 'rack.input'=>io).must_equal 'foobar'

    s, h, b = req('/foo')
    s.must_equal 200
    field = h['field']
    token = Regexp.escape(h['token'])
    h['tag'].must_match(/\A<input type="hidden" name="#{field}" value="#{token}" \/>\z/)
    h['metatag'].must_match(/\A<meta name="#{field}" content="#{token}" \/>\z/)
    b.must_equal ['g']
    s, _, b = req('/foo', 'REQUEST_METHOD'=>'POST', 'rack.input'=>io, "HTTP_#{h['header']}"=>h['token'])
    s.must_equal 200
    b.must_equal ['p']

    sub_app.plugin :csrf, :skip_middleware=>true
    body('/foo/bar', 'REQUEST_METHOD'=>'POST', 'rack.input'=>io).must_equal 'foobar'

    @app = sub_app
    s, _, b = req('/bar', 'REQUEST_METHOD'=>'POST', 'rack.input'=>io)
    s.must_equal 200
    b.must_equal ['foobar']
  end
end unless Rack.release >= '2.3' && defined?(Rack::Csrf::VERSION) && Rack::Csrf::VERSION < '2.7'
end
