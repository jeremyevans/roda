require_relative "../spec_helper"

describe "sec_fetch_site_csrf plugin" do 
  def sec_fetch_site_app(opts={}, &block)
    app(:bare) do
      plugin(:sec_fetch_site_csrf, opts, &block)
      route do |r|
        check_sec_fetch_site!
        r.post("session"){session[:a].inspect}
        "allowed"
      end
    end
  end

  it "allows all GET requests and allows POST requests only for same-origin requests" do
    sec_fetch_site_app
    body.must_equal 'allowed'

    body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    body("REQUEST_METHOD"=>'DELETE', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    body("REQUEST_METHOD"=>'PATCH', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    body("REQUEST_METHOD"=>'PUT', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'

    proc{body("REQUEST_METHOD"=>'POST')}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
    proc{body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-site')}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
    proc{body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'none')}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
    proc{body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'cross-site')}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure

    proc{body("REQUEST_METHOD"=>'DELETE', 'HTTP_SEC_FETCH_SITE'=>'same-site')}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
    proc{body("REQUEST_METHOD"=>'PATCH', 'HTTP_SEC_FETCH_SITE'=>'same-site')}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
    proc{body("REQUEST_METHOD"=>'PUT', 'HTTP_SEC_FETCH_SITE'=>'same-site')}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
  end

  it "supports :allow_missing option" do
    sec_fetch_site_app(:allow_missing=>true)
    body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    body("REQUEST_METHOD"=>'POST').must_equal 'allowed'
    proc{body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-site')}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
  end

  it "supports :allow_none option" do
    sec_fetch_site_app(:allow_none=>true)
    body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'none').must_equal 'allowed'
    proc{body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-site')}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
  end

  it "supports :allow_same_site option" do
    sec_fetch_site_app(:allow_same_site=>true)
    body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-site').must_equal 'allowed'
    proc{body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'none')}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
  end

  it "supports :check_request_methods option" do
    sec_fetch_site_app(:check_request_methods=>["GET"])
    proc{body}.must_raise Roda::RodaPlugins::SecFetchSiteCsrf::CsrfFailure
    body('HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    body("REQUEST_METHOD"=>'POST').must_equal 'allowed'
  end

  it "allows configuring CSRF failure action with :csrf_failure => :empty_403 option" do
    sec_fetch_site_app(:csrf_failure=>:empty_403)
    body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    req("REQUEST_METHOD"=>'POST').must_equal [403, {RodaResponseHeaders::CONTENT_TYPE=>'text/html', RodaResponseHeaders::CONTENT_LENGTH=>'0'}, []]
  end

  it "allows configuring CSRF failure action with :csrf_failure => :clear_session option" do
    sec_fetch_site_app(:csrf_failure=>:clear_session)
    body("/session", "REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-origin', 'rack.session'=>{a: 1}).must_equal '1'
    body("/session", "REQUEST_METHOD"=>'POST', 'rack.session'=>{a: 1}).must_equal 'nil'
  end

  it "allows configuring CSRF failure action via a plugin block" do
    sec_fetch_site_app{|r| r.path + '2'}
    body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    body("REQUEST_METHOD"=>'POST').must_equal '/2'
  end

  it "allows overriding failure behavior by passing block to check_sec_fetch_site! method" do
    app(:bare) do
      plugin(:sec_fetch_site_csrf)
      route do |r|
        check_sec_fetch_site!{r.path + '2'}
        "allowed"
      end
    end
    body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    body("REQUEST_METHOD"=>'POST').must_equal '/2'
  end

  it "allows plugin block to integrate with route_block_args plugin" do
    app(:bare) do
      plugin :route_block_args do
        [request, request.path, response]
      end
      plugin(:sec_fetch_site_csrf){|r, path, res| res.write(path); res.write('2')}
      route do |r|
        check_sec_fetch_site!
        "allowed"
      end
    end
    body("REQUEST_METHOD"=>'POST', 'HTTP_SEC_FETCH_SITE'=>'same-origin').must_equal 'allowed'
    body("REQUEST_METHOD"=>'POST').must_equal '/2'
  end

  it "raises Error if configuring plugin with invalid :csrf_failure option" do
    proc{sec_fetch_site_app(:csrf_failure=>:foo)}.must_raise Roda::RodaError
  end
end
