require_relative "../spec_helper"

begin
  require 'tilt'
  require 'tilt/erb'
  require 'tilt/string'
  require_relative '../../lib/roda/plugins/render'
rescue LoadError
  warn "tilt not installed, skipping part plugin test"  
else
describe "part plugin" do
  before do
    app(:bare) do
      plugin :render, :views=>"./spec/views", :check_paths=>true
      plugin :part

      route do |r|
        r.on "home" do
          part('layout', :title=>"Home"){part("home", :name => "Agent Smith", :title => "Home")}
        end

        r.on "about" do
          part("about", :title => "About Roda")
        end

        r.on "inline" do
          part({:inline=>"Hello <%= name %>"}, :name => "Agent Smith")
        end

        r.on "path" do
          part({:path=>"./spec/views/about.erb"}, :title => "Path")
        end

        r.on "render-block" do
          part('layout', :title=>"Home"){part("about", :title => "About Roda")}
        end
      end
    end
  end

  it "default actions" do
    body("/about").strip.must_equal "<h1>About Roda</h1>"
    body("/home").strip.must_equal "<title>Roda: Home</title>\n<h1>Home</h1>\n<p>Hello Agent Smith</p>"
    body("/inline").strip.must_equal "Hello Agent Smith"
    body("/path").strip.must_equal "<h1>Path</h1>"
    body("/render-block").strip.must_equal "<title>Roda: Home</title>\n<h1>About Roda</h1>"
  end

  it "with str as engine" do
    app.plugin :render, :engine => "str"
    body("/about").strip.must_equal "<h1>About Roda</h1>"
    body("/home").strip.must_equal "<title>Roda: Home</title>\n<h1>Home</h1>\n<p>Hello Agent Smith</p>"
    body("/inline").strip.must_equal "Hello <%= name %>"
  end

  if Roda::RodaPlugins::Render::FIXED_LOCALS_COMPILED_METHOD_SUPPORT
    [true, false].each do |cache_plugin_option|
      multiplier = cache_plugin_option ? 1 : 2

      it "support fixed locals in layout templates with plugin option :cache=>#{cache_plugin_option}" do
        template = "comp_test"

        app(:bare) do
          plugin :render, :views=>'spec/views/fixed', :cache=>cache_plugin_option, :template_opts=>{:extract_fixed_locals=>true}
          plugin :part
          route do |_|
            part("layout", title: "Home"){part(template)}
          end
        end

        layout_key = [:_render_locals, "layout"]
        template_key = [:_render_locals, template]
        app.render_opts[:template_method_cache][template_key].must_be_nil
        app.render_opts[:template_method_cache][layout_key].must_be_nil
        body.strip.must_equal "<title>Roda: Home</title>\nct"
        app.render_opts[:template_method_cache][template_key].must_be_kind_of(Array)
        app.render_opts[:template_method_cache][layout_key].must_be_kind_of(Array)
        body.strip.must_equal "<title>Roda: Home</title>\nct"
        app.render_opts[:template_method_cache][template_key].must_be_kind_of(Array)
        app.render_opts[:template_method_cache][layout_key].must_be_kind_of(Array)
        body.strip.must_equal "<title>Roda: Home</title>\nct"
        app.render_opts[:template_method_cache][template_key].must_be_kind_of(Array)
        app.render_opts[:template_method_cache][layout_key].must_be_kind_of(Array)
        app::RodaCompiledTemplates.private_instance_methods.length.must_equal(multiplier * 2)
      end

      it "support fixed locals in render templates with plugin option :cache=>#{cache_plugin_option}" do
        template = "local_test"

        app(:bare) do
          plugin :render, :views=>'spec/views/fixed', :cache=>cache_plugin_option, :template_opts=>{:extract_fixed_locals=>true}
          plugin :part
          route do |_|
            part(template, title: 'ct')
          end
        end

        key = [:_render_locals, template]
        app.render_opts[:template_method_cache][key].must_be_nil
        body.strip.must_equal "ct"
        app.render_opts[:template_method_cache][key].must_be_kind_of(Array)
        body.strip.must_equal "ct"
        app.render_opts[:template_method_cache][key].must_be_kind_of(Array)
        body.strip.must_equal "ct"
        app.render_opts[:template_method_cache][key].must_be_kind_of(Array)
        app::RodaCompiledTemplates.private_instance_methods.length.must_equal multiplier
      end

      [true, false].each do |assume_fixed_locals_option|
        [true, false].each do |freeze_app|
          it "caches expectedly for cache: #{cache_plugin_option}, assume_fixed_locals: #{assume_fixed_locals_option} options when #{'not ' unless freeze_app}freezing app" do
            template = "opt_local_test"

            app(:bare) do
              plugin :render, :views=>'spec/views/fixed', :cache=>cache_plugin_option, :template_opts=>{:extract_fixed_locals=>true}, :assume_fixed_locals=>assume_fixed_locals_option, :layout=>false
              plugin :part
              route do |r|
                r.is 'a' do
                  render(template)
                end
                part(template, title: 'ct')
              end 
              freeze if freeze_app
            end

            cache_size = 1
            key = if assume_fixed_locals_option
              template
            else
              [:_render_locals, template]
            end
            cache = app.render_opts[:template_method_cache]
            cache[key].must_be_nil
            body.strip.must_equal "ct"
            cache[key].must_be_kind_of(Array)
            cache.instance_variable_get(:@hash).length.must_equal cache_size
            body.strip.must_equal "ct"
            cache[key].must_be_kind_of(Array)
            cache.instance_variable_get(:@hash).length.must_equal cache_size
            body.strip.must_equal "ct"
            cache[key].must_be_kind_of(Array)
            cache.instance_variable_get(:@hash).length.must_equal cache_size
            app::RodaCompiledTemplates.private_instance_methods.length.must_equal multiplier

            cache_size = 2 unless assume_fixed_locals_option
            key = template
            body('/a').strip.must_equal "ct"
            cache[key].must_be_kind_of(Array)
            cache.instance_variable_get(:@hash).length.must_equal cache_size
            body('/a').strip.must_equal "ct"
            cache[key].must_be_kind_of(Array)
            cache.instance_variable_get(:@hash).length.must_equal cache_size
            body('/a').strip.must_equal "ct"
            cache[key].must_be_kind_of(Array)
            cache.instance_variable_get(:@hash).length.must_equal cache_size
            app::RodaCompiledTemplates.private_instance_methods.length.must_equal(multiplier * cache_size)
          end
        end
      end
    end
  end
end
end
