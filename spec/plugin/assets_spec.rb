require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

begin
  require 'tilt'
  require 'tilt/sass'
  require 'tilt/coffee'
rescue LoadError
  warn 'tilt not installed, skipping assets plugin test'
else
  describe 'assets plugin' do
    before do
      app(:bare) do
        plugin(:assets, {
          path: './spec/dummy/assets',
          css_engine: 'scss',
          js_engine: 'coffee',
          headers: {
            "Cache-Control"             => 'public, max-age=2592000, no-transform',
            'Connection'                => 'keep-alive',
            'Age'                       => '25637',
            'Strict-Transport-Security' => 'max-age=31536000',
            'Content-Disposition'       => 'inline'
          }
        })

        assets_opts[:css] = ['app', '../raw.css']
        assets_opts[:js]  = { head: ['app'] }

        route do |r|
          r.assets

          r.is 'test' do
            response.write assets :css
            response.write assets [:js, :head]
          end
        end
      end
    end

    it 'should contain proper configuration' do
      app.assets_opts[:path].should == './spec/dummy/assets'
      app.assets_opts[:css].should include('app')
    end

    it 'should serve proper assets' do
      body('/assets/css/app.css').should include('color: red')
      body('/assets/css/%242E%242E/raw.css').should include('color: blue')
      body('/assets/js/head/app.js').should include('console.log')
      body('/assets/css/http://google.com').should include('google.com')
    end

    it 'should contain proper assets html tags' do
      html = body '/test'
      html.scan(/<link/).length.should eq 2
      html.scan(/<script/).length.should eq 1
      html.should include('link')
      html.should include('script')
    end

    it 'should only show one link when concat/compile is true' do
      app.assets_opts[:concat] = true
      html = body '/test'
      html.scan(/<link/).length.should eq 1

      app.assets_opts[:compiled] = true
      html = body '/test'
      html.scan(/<link/).length.should eq 1
    end

    it 'should join all files when concat is true' do
      app.assets_opts[:concat] = true
      path = app.assets_opts[:concat_name] + '/css/123'
      css = body("/assets/css/#{path}.css")
      css.should include('color: red')
      css.should include('color: blue')
    end

    it 'should grab compiled files' do
      app.compile_assets
      app.assets_opts[:compiled] = true
      path = app.assets_opts[:compiled_name] + '/js-head/123'
      js = body("/assets/js/#{path}.js")
      js.should include('console.log')
    end
  end
end
