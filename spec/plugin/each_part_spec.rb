require_relative "../spec_helper"

begin
  require 'tilt'
  require 'tilt/string'
  require 'tilt/rdoc'
  require_relative '../../lib/roda/plugins/render'
rescue LoadError
  warn "tilt not installed, skipping each_part plugin test"  
else
describe "each_part plugin" do 
  [true, false].each do |cache|
    it "calls render with each argument, returning joined string with all results in cache: #{cache} mode" do
      app(:bare) do
        plugin :render, :views=>'spec/views', :engine=>'str', :cache=>cache
        plugin :each_part

        o = Object.new
        def o.to_s; 'each' end

        route do |r|
          r.root do
            each_part([1,2,3], :each)
          end

          r.is 'c' do
            each_part([1,2,3], :each, :foo=>4)
          end

          r.is 'e' do
            each_part([1,2,3], o)
          end

          r.is 'g' do
            each_part([1,2,3], "each.foo")
          end

          r.is 'h' do
            body = String.new
            each_part([1,2,3], :each){|t| body << t << " "}
            body
          end
        end
      end

      2.times do
        3.times do
          body.must_equal "r-1-\nr-2-\nr-3-\n"
          body("/c").must_equal "r-1-4\nr-2-4\nr-3-4\n"
          body("/e").must_equal "r-1-\nr-2-\nr-3-\n"
          body("/g").must_equal "r-1-\nr-2-\nr-3-\n"
          body("/h").must_equal "r-1-\n r-2-\n r-3-\n "
        end
        app.opts[:render] = app.opts[:render].dup
        app.opts[:render].delete(:template_method_cache)
      end
    end

    it "bases local name on basename of template in cache: #{cache} mode" do
      app(:bare) do
        plugin :render, :views=>'spec', :engine=>'str', :cache=>cache
        plugin :each_part

        route do |r|
          r.root do
            each_part([1,2,3], "views/each")
          end
        end
      end

      3.times do
        body.must_equal "r-1-\nr-2-\nr-3-\n"
      end
    end

    if Roda::RodaPlugins::Render::COMPILED_METHOD_SUPPORT
      it "calls render with each argument, handling template engines that don't support compilation in cache: #{cache} mode" do
        app(:bare) do
          plugin :render, :views=>'spec/views', :engine=>'rdoc', :cache=>cache
          plugin :each_part

          route do |r|
            r.root do
              each_part([1], :a)
            end
          end
        end

        3.times do
          body.strip.must_equal "<p># a # * b</p>"
        end
      end
    end
  end

  if Roda::RodaPlugins::Render::FIXED_LOCALS_COMPILED_METHOD_SUPPORT
    [true, false].each do |cache_plugin_option|
      multiplier = cache_plugin_option ? 1 : 2

      it "support fixed locals in layout templates with plugin option :cache=>#{cache_plugin_option}" do
        template = "comp_each_test"

        app(:bare) do
          plugin :render, :views=>'spec/views/fixed', :layout_opts=>{:locals=>{:title=>"Home"}}, :cache=>cache_plugin_option, :template_opts=>{:extract_fixed_locals=>true}
          plugin :each_part
          route do |_|
            each_part([1], template)
          end
        end

        key = [:_render_locals, "comp_each_test"]
        app.render_opts[:template_method_cache][key].must_be_nil
        body.strip.must_equal "ct"
        app.render_opts[:template_method_cache][key].must_be_kind_of(Array)
        body.strip.must_equal "ct"
        app.render_opts[:template_method_cache][key].must_be_kind_of(Array)
        body.strip.must_equal "ct"
        app.render_opts[:template_method_cache][key].must_be_kind_of(Array)
        app::RodaCompiledTemplates.private_instance_methods.length.must_equal multiplier
      end

      it "support fixed locals in render templates with plugin option :cache=>#{cache_plugin_option}" do
        template = "local_test"

        app(:bare) do
          plugin :render, :views=>'spec/views/fixed', :cache=>cache_plugin_option, :template_opts=>{:extract_fixed_locals=>true}
          plugin :each_part
          route do |_|
            each_part([1], template, title: 'ct')
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
          it "caches expectedly for cache: #{cache_plugin_option}, assume_fixed_locals: #{assume_fixed_locals_option} options, with #{'un' unless freeze_app}frozen app" do
            template = "opt_local_test"

            app(:bare) do
              plugin :render, :views=>'spec/views/fixed', :cache=>cache_plugin_option, :template_opts=>{:extract_fixed_locals=>true}, :assume_fixed_locals=>assume_fixed_locals_option, :layout=>false
              plugin :each_part
              route do |r|
                r.is 'a' do
                  each_part([1], template)
                end
                r.is 'b' do
                  s = String.new
                  each_part([1], template){|v| s << v}
                  s
                end
                each_part([1], template, title: 'ct')
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

            body('/b').strip.must_equal "ct"
            cache[key].must_be_kind_of(Array)
            cache.instance_variable_get(:@hash).length.must_equal cache_size
            body('/b').strip.must_equal "ct"
            cache[key].must_be_kind_of(Array)
            cache.instance_variable_get(:@hash).length.must_equal cache_size
            body('/b').strip.must_equal "ct"
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
