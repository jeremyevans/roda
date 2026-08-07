require_relative "../spec_helper"

describe "permissions_policy plugin" do 
  it "does not add header if no options are set" do
    app(:permissions_policy){|_| 'a'}
    header(RodaResponseHeaders::PERMISSIONS_POLICY, "/a").must_be_nil
  end

  it "sets Permissions-Policy header" do
    app(:bare) do
      plugin :permissions_policy do |pp|
        pp.camera :none
        pp.fullscreen :self
        pp.midi :self, 'http://example.com'
        pp.geolocation :all
      end

      route do |r|
        r.get 'ro' do
          permissions_policy.report_only
          ''
        end

        r.get 'nro' do
          permissions_policy.report_only
          permissions_policy.report_only(false)
          permissions_policy.report_only?.inspect
        end

        r.get 'get' do
          permissions_policy.get_geolocation.inspect
        end

        r.get 'add' do
          permissions_policy.add_camera('http://foo.com', 'https://bar.com')
          permissions_policy.add_geolocation('http://foo.com', 'https://bar.com')
          permissions_policy.add_fullscreen('https://foo.com', 'http://bar.com')
          permissions_policy.add_midi('https://foo.com')
          ''
        end

        r.get 'empty' do
          permissions_policy.add_geolocation
          ''
        end

        r.get 'set' do
          permissions_policy.fullscreen('http://foobar.com', 'https://barfoo.com')
          ''
        end

        r.get 'block' do
          permissions_policy do |pp|
            pp.geolocation(:src, 'http://foo.com', 'https://bar.com')
            pp.camera :all
            pp.add_midi
            pp.fullscreen
            pp.report_only
          end
          ''
        end

        r.get 'clear' do
          permissions_policy do |pp|
            pp.clear
            pp.add_geolocation('http://foo.com', 'https://bar.com')
          end
          ''
        end

        'a'
      end
    end

    v = 'camera=(), fullscreen=(self), midi=(self "http://example.com"), geolocation=*'

    header(RodaResponseHeaders::PERMISSIONS_POLICY, "/a").must_equal v

    header(RodaResponseHeaders::PERMISSIONS_POLICY, "/nro").must_equal v
    header(RodaResponseHeaders::PERMISSIONS_POLICY_REPORT_ONLY, "/nro").must_be_nil
    body("/nro").must_equal 'false'

    header(RodaResponseHeaders::PERMISSIONS_POLICY_REPORT_ONLY, "/ro").must_equal v
    header(RodaResponseHeaders::PERMISSIONS_POLICY, "/ro").must_be_nil

    body('/get').must_equal ':all'

    header(RodaResponseHeaders::PERMISSIONS_POLICY, "/add").must_equal 'camera=("http://foo.com" "https://bar.com"), fullscreen=(self "https://foo.com" "http://bar.com"), midi=(self "http://example.com" "https://foo.com"), geolocation=*'

    header(RodaResponseHeaders::PERMISSIONS_POLICY, "/empty").must_equal 'camera=(), fullscreen=(self), midi=(self "http://example.com"), geolocation=*'

    header(RodaResponseHeaders::PERMISSIONS_POLICY, "/set").must_equal 'camera=(), fullscreen=("http://foobar.com" "https://barfoo.com"), midi=(self "http://example.com"), geolocation=*'

    header(RodaResponseHeaders::PERMISSIONS_POLICY_REPORT_ONLY, "/block").must_equal 'camera=*, midi=(self "http://example.com"), geolocation=(src "http://foo.com" "https://bar.com")'

    header(RodaResponseHeaders::PERMISSIONS_POLICY, "/clear").must_equal 'geolocation=("http://foo.com" "https://bar.com")'
  end

  it "raises error for unsupported Permission-Policy values" do
    app{|_|}
    proc{app.plugin(:permissions_policy){|pp| pp.fullscreen Object.new}}.must_raise Roda::RodaError
    proc{app.plugin(:permissions_policy){|pp| pp.fullscreen []}}.must_raise Roda::RodaError
    proc{app.plugin(:permissions_policy){|pp| pp.fullscreen [:a]}}.must_raise Roda::RodaError
    proc{app.plugin(:permissions_policy){|pp| pp.fullscreen [:a, :b, :c]}}.must_raise Roda::RodaError
  end

  it "supports :default plugin option" do
    app(:bare) do
      plugin :permissions_policy, :default=>:none
      route do |r|
       ''
      end
    end

    header(RodaResponseHeaders::PERMISSIONS_POLICY).must_equal Roda::RodaPlugins::PermissionsPolicy.const_get(:SUPPORTED_SETTINGS).map{|s| "#{s}=()"}.join(', ')
  end

  it "supports all documented settings" do
    app(:permissions_policy) do |r|
      permissions_policy.send(r.path[1..-1], :self)
    end

    Roda::RodaPlugins::PermissionsPolicy.const_get(:SUPPORTED_SETTINGS).each do |setting|
      header(RodaResponseHeaders::PERMISSIONS_POLICY, "/#{setting.tr('-', '_')}").must_equal "#{setting}=(self)"
    end
  end

  it "does not override existing heading" do
    app(:permissions_policy) do |r|
      permissions_policy.fullscreen :self
      response[RodaResponseHeaders::PERMISSIONS_POLICY] = "foo"
      ''
    end
    header(RodaResponseHeaders::PERMISSIONS_POLICY).must_equal "foo"
  end

  it "should not set header when using response.skip_permissions_policy!" do
    app(:bare) do
      plugin :permissions_policy do |pp|
        pp.fullscreen :self
      end

      route do |r|
        response.skip_permissions_policy!
        ''
      end
    end
    header(RodaResponseHeaders::PERMISSIONS_POLICY).must_be_nil
  end

  it "works with error_handler" do
    app(:bare) do
      plugin(:error_handler){|_| ''}
      plugin :permissions_policy do |pp|
        pp.fullscreen :self
        pp.camera :self, 'https://example.com'
        pp.midi :none
      end

      route do |r|
        r.get 'a' do
          permissions_policy.fullscreen 'foo.com'
          raise
        end

        raise
      end
    end

    header(RodaResponseHeaders::PERMISSIONS_POLICY).must_equal 'fullscreen=(self), camera=(self "https://example.com"), midi=()'

    # Don't include updates before the error
    header(RodaResponseHeaders::PERMISSIONS_POLICY, '/a').must_equal 'fullscreen=(self), camera=(self "https://example.com"), midi=()'
  end
end
