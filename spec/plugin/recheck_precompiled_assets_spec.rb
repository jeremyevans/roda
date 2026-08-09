require_relative "../spec_helper"
require 'fileutils'

run_tests = true
begin
  begin
    require 'tilt'
  rescue LoadError
    warn "tilt not installed, skipping assets plugin test"
    run_tests = false
  end
end

if run_tests
  pid_dir = "spec/pid-#{$$}"
  assets_dir = File.join(pid_dir, "tmp")
  metadata_file = File.expand_path(File.join(assets_dir, 'precompiled.json'))
  describe 'recheck_precompiled_assets plugin' do
    define_method(:compile_assets) do |opts={}|
      Class.new(Roda) do
        plugin :assets, {:css => 'app.str', :path => assets_dir, :css_dir=>nil, :precompiled=>metadata_file, :public=>assets_dir, :prefix=>nil, :js_compressor=>:none, :css_compressor=>:none}.merge!(opts)
        compile_assets
      end
    end

    before do
      Dir.mkdir(pid_dir) unless File.directory?(pid_dir)
      Dir.mkdir(assets_dir) unless File.directory?(assets_dir)
      FileUtils.cp('spec/assets/css/app.str', assets_dir)
      FileUtils.cp('spec/assets/js/head/app.js', assets_dir)
      compile_assets
      File.utime(Time.now, Time.now - 20, metadata_file)

      app(:bare) do
        plugin :assets, :public => assets_dir, :prefix=>nil, :precompiled=>metadata_file
        plugin :recheck_precompiled_assets

        route do |r|
          r.assets
          "#{assets(:css)}\n#{assets(:js)}"
        end
      end
    end
    after do
      FileUtils.rm_r(pid_dir) if File.directory?(pid_dir)
    end

    it 'should support :recheck_precompiled option to recheck precompiled file for new precompilation data' do
      css_hash = app.assets_opts[:compiled]['css']
      app.assets_opts[:compiled]['js'].must_be_nil
      body.scan("href=\"/app.#{css_hash}.css\"").length.must_equal 1
      body("/app.#{css_hash}.css").must_match(/color:\s*red/)

      css_file = File.join(assets_dir, 'app.str')
      File.write(css_file, File.read(css_file).sub('red', 'blue'))
      compile_assets
      File.utime(Time.now, Time.now - 10, metadata_file)

      app.assets_opts[:compiled]['css'].must_equal css_hash
      body.scan("href=\"/app.#{css_hash}.css\"").length.must_equal 1
      body("/app.#{css_hash}.css").must_match(/color:\s*red/)
      css2_hash = nil

      2.times do
        app.recheck_precompiled_assets
        css2_hash = app.assets_opts[:compiled]['css']
        css2_hash.wont_equal css_hash
        body.scan("href=\"/app.#{css2_hash}.css\"").length.must_equal 1
        body("/app.#{css2_hash}.css").must_match(/color:\s*blue/)
        body("/app.#{css_hash}.css").must_match(/color:\s*red/)
      end

      compile_assets(:js=>'app.js', :js_dir=>nil)
      app.recheck_precompiled_assets
      js_hash = app.assets_opts[:compiled]['js']
      body.scan("src=\"/app.#{js_hash}.js\"").length.must_equal 1
      body("/app.#{js_hash}.js").must_match(/console\.log\(.test.\)/)

      app.assets_opts[:compiled].replace({})
      app.compile_assets
      body.strip.must_be_empty
      app.plugin :assets, :css => 'app.str', :path => assets_dir, :css_dir=>nil, :css_opts => {:cache=>false}
      app.compile_assets
      body.scan("href=\"/app.#{css2_hash}.css\"").length.must_equal 1
      body("/app.#{css2_hash}.css").must_match(/color:\s*blue/)
    end
  end

  describe 'recheck_precompiled_assets plugin' do
    it "should not allow loading if not using assets plugin" do
      proc{app(:recheck_precompiled_assets)}.must_raise Roda::RodaError
    end

    it "should not allow loading if using assets plugin without :precompiled option" do
      proc do
        app(:bare) do
          plugin :assets
          plugin :recheck_precompiled_assets
        end
      end.must_raise Roda::RodaError
    end
  end
end
