require_relative "../spec_helper"

begin
  require 'tilt'
  require 'tilt/erb'
  require 'tilt/string'
  require_relative '../../lib/roda/plugins/render'
rescue LoadError
  warn "tilt not installed, skipping render plugin test"  
else
describe "render plugin" do
  before do
    app(:bare) do
      plugin :render, :views=>"./spec/views", :check_paths=>true

      route do |r|
        r.on "home" do
          view("home", :locals=>{:name => "Agent Smith", :title => "Home"}, :layout_opts=>{:locals=>{:title=>"Home"}})
        end

        r.on "about" do
          render("about", :locals=>{:title => "About Roda"})
        end

        r.on "inline" do
          view(:inline=>"Hello <%= name %>", :locals=>{:name => "Agent Smith"}, :layout=>nil)
        end

        r.on "path" do
          render(:path=>"./spec/views/about.erb", :locals=>{:title => "Path"}, :layout_opts=>{:locals=>{:title=>"Home"}})
        end

        r.on "content" do
          view(:content=>'bar', :layout_opts=>{:locals=>{:title=>"Home"}})
        end

        r.on "render-block" do
          render('layout', :locals=>{:title=>"Home"}){render("about", :locals=>{:title => "About Roda"})}
        end

        r.on "view-block" do
          view(:layout, :locals=>{:title=>"A"}, :layout_opts=>{:locals=>{:title=>"B"}}){render("about", :locals=>{:title => "About Roda"})}
        end
      end
    end
  end

  it "default actions" do
    body("/about").strip.must_equal "<h1>About Roda</h1>"
    body("/home").strip.must_equal "<title>Roda: Home</title>\n<h1>Home</h1>\n<p>Hello Agent Smith</p>"
    body("/inline").strip.must_equal "Hello Agent Smith"
    body("/path").strip.must_equal "<h1>Path</h1>"
    body("/content").strip.must_equal "<title>Roda: Home</title>\nbar"
    body("/render-block").strip.must_equal "<title>Roda: Home</title>\n<h1>About Roda</h1>"
    body("/view-block").strip.must_equal "<title>Roda: B</title>\n<title>Roda: A</title>\n<h1>About Roda</h1>"
  end

  it "with str as engine" do
    app.plugin :render, :engine => "str"
    body("/about").strip.must_equal "<h1>About Roda</h1>"
    body("/home").strip.must_equal "<title>Roda: Home</title>\n<h1>Home</h1>\n<p>Hello Agent Smith</p>"
    body("/inline").strip.must_equal "Hello <%= name %>"
  end

  it "custom default layout support" do
    app.plugin :render, :layout => "layout-alternative"
    body("/home").strip.must_equal "<title>Alternative Layout: Home</title>\n<h1>Home</h1>\n<p>Hello Agent Smith</p>"
  end

  it "using hash for :layout" do
    app.plugin :render, :layout => {:inline=> 'a<%= yield %>b'}
    body("/home").strip.must_equal "a<h1>Home</h1>\n<p>Hello Agent Smith</p>\nb"
  end
end

describe "render plugin" do
  iv = "iv-#{$$}"
  file = "spec/#{iv}.erb"
  dependent_file = "spec/tmp-#{$$}.txt"
  before do
    File.binwrite(file, File.binread("spec/views/iv.erb"))
  end
  after do
    [file, dependent_file].each do |f|
      File.delete(f) if File.file?(f)
    end
  end

  it "checks mtime of dependent files if :dependencies render method option is used" do
    File.write(dependent_file, '')

    app(:bare) do
      plugin :render, :views=>"./spec", :cache=>false

      route do |r|
        @a = 'a'
        render(iv, :dependencies=>[dependent_file])
      end
    end

    t = Time.now+1
    body.strip.must_equal "a"

    File.binwrite(file, File.binread(file) + "b")
    File.utime(t, t+1, dependent_file)
    body.delete("\n").must_equal "ab"
  end

  [{:cache=>false}, {:explicit_cache=>true}, {:check_template_mtime=>true}].each do |cache_plugin_opts|
    it "checks mtime if #{cache_plugin_opts} plugin option is used" do
      app(:bare) do
        plugin :render, {:views=>"./spec"}.merge!(cache_plugin_opts)

        route do |r|
          @a = 'a'
          render(iv)
        end
      end

      t = Time.now
      body.strip.must_equal "a"

      File.binwrite(file, File.binread(file) + "b")
      File.utime(t, t+1, file)
      body.delete("\n").must_equal "ab"

      File.binwrite(file, File.binread(file) + "c")
      File.utime(t, t+2, file)
      body.delete("\n").must_equal "abc"

      mtime = File.mtime(file)
      File.binwrite(file, File.binread(file) + "d")
      File.utime(t, mtime, file)
      body.delete("\n").must_equal "abc"

      File.delete(file)
      body.delete("\n").must_equal "abc"
    end
  end

  it "does not update mtime if there was an error rebuilding the template" do
    app(:bare) do
      plugin :render, :views=>"./spec", :cache=>false

      route do |r|
        @a = 'a'
        render(iv)
      end
    end

    t = Time.now
    body.strip.must_equal "a"

    content = File.binread(file)
    File.binwrite(file, content + "<% end %>")
    File.utime(t, t+1, file)
    proc{body}.must_raise SyntaxError
    proc{body}.must_raise SyntaxError

    File.binwrite(file, content + "b")
    File.utime(t, t+1, file)
    body.delete("\n").must_equal "ab"
  end

  it "does not check mtime if :cache render option is used" do
    app(:bare) do
      plugin :render, :views=>"./spec", :cache=>false

      route do |r|
        @a = 'a'
        render(iv, :cache=>true)
      end
    end

    t = Time.now+1
    body.strip.must_equal "a"

    File.binwrite(file, File.binread(file) + "b")
    File.utime(t, t+1, file)
    body.delete("\n").must_equal "a"
  end
end

describe "render plugin" do
  it "simple layout support" do
    app(:bare) do
      plugin :render
      
      route do |r|
        render(:path=>"spec/views/layout-yield.erb") do
          render(:path=>"spec/views/content-yield.erb")
        end
      end
    end

    body.squeeze("\n").must_equal "Header\nThis is the actual content.\nFooter\n"
  end

  it "layout changing does not use cached template method" do
    app(:bare) do
      plugin :render, :views=>'spec/views', :layout=>'layout-yield'
      
      route do |r|
        view(:content=>'1')
      end
    end

    body.squeeze("\n").sub("\nFooter", 'Footer').must_equal "Header\n1Footer\n"
    app.plugin :render, :layout=>'layout-yield2'
    body.squeeze("\n").sub("\nFooter", 'Footer').must_equal "Header2\n1Footer2\n"
  end

  it "should have :layout_opts=>:views plugin option respect :root app option" do
    app(:bare) do
      self.opts[:root] = 'spec'
      plugin :render, :layout_opts=>{:views=>"views"}, :allowed_paths=>["spec/views"]

      route do |r|
        view(:content=>'a', :layout_opts=>{:locals=>{:title=>"Home"}})
      end
    end

    body.strip.must_equal "<title>Roda: Home</title>\na"
    app.freeze
    body.strip.must_equal "<title>Roda: Home</title>\na"
  end

  it "views without default layouts" do
    app(:bare) do
      plugin :render, :views=>"./spec/views", :layout=>false
      
      route do |r|
        view("home", :locals=>{:name=>"Agent Smith", :title=>"Home"})
      end
    end

    body.strip.must_equal "<h1>Home</h1>\n<p>Hello Agent Smith</p>"
    app.freeze
    body.strip.must_equal "<h1>Home</h1>\n<p>Hello Agent Smith</p>"
  end

  it "layout overrides" do
    app(:bare) do
      plugin :render, :views=>"./spec/views"
      
      route do |r|
        view("home", :locals=>{:name=>"Agent Smith", :title=>"Home" }, :layout=>"layout-alternative", :layout_opts=>{:locals=>{:title=>"Home"}})
      end
    end

    body.strip.must_equal "<title>Alternative Layout: Home</title>\n<h1>Home</h1>\n<p>Hello Agent Smith</p>"
  end

  it ":layout=>true/false/string/hash/not-present respects plugin layout switch and template" do
    app(:bare) do
      plugin :render, :views=>"./spec/views", :layout_opts=>{:template=>'layout-yield'}
      
      route do |r|
        opts = {:content=>'bar'}
        opts[:layout] = true if r.path == '/'
        opts[:layout] = false if r.path == '/f'
        opts[:layout] = 'layout' if r.path == '/s'
        opts[:layout] = {:template=>'layout'} if r.path == '/h'
        opts[:layout_opts] = {:locals=>{:title=>'a'}}
        view(opts)
      end
    end

    body.delete("\n").must_equal "HeaderbarFooter"
    body('/a').delete("\n").must_equal "HeaderbarFooter"
    body('/f').delete("\n").must_equal "bar"
    body('/s').delete("\n").must_equal "<title>Roda: a</title>bar"
    body('/h').delete("\n").must_equal "<title>Roda: a</title>bar"

    app.plugin :render
    body.delete("\n").must_equal "HeaderbarFooter"
    body('/a').delete("\n").must_equal "HeaderbarFooter"
    body('/f').delete("\n").must_equal "bar"
    body('/s').delete("\n").must_equal "<title>Roda: a</title>bar"
    body('/h').delete("\n").must_equal "<title>Roda: a</title>bar"

    app.plugin :render, :layout=>true
    body.delete("\n").must_equal "HeaderbarFooter"
    body('/a').delete("\n").must_equal "HeaderbarFooter"
    body('/f').delete("\n").must_equal "bar"
    body('/s').delete("\n").must_equal "<title>Roda: a</title>bar"
    body('/h').delete("\n").must_equal "<title>Roda: a</title>bar"

    app.plugin :render, :layout=>'layout-alternative'
    body.delete("\n").must_equal "<title>Alternative Layout: a</title>bar"
    body('/a').delete("\n").must_equal "<title>Alternative Layout: a</title>bar"
    body('/f').delete("\n").must_equal "bar"
    body('/s').delete("\n").must_equal "<title>Roda: a</title>bar"
    body('/h').delete("\n").must_equal "<title>Roda: a</title>bar"

    app.plugin :render, :layout=>nil
    body.delete("\n").must_equal "HeaderbarFooter"
    body('/a').delete("\n").must_equal "bar"
    body('/f').delete("\n").must_equal "bar"
    body('/s').delete("\n").must_equal "<title>Roda: a</title>bar"
    body('/h').delete("\n").must_equal "<title>Roda: a</title>bar"

    app.plugin :render, :layout=>false
    body.delete("\n").must_equal "HeaderbarFooter"
    body('/a').delete("\n").must_equal "bar"
    body('/f').delete("\n").must_equal "bar"
    body('/s').delete("\n").must_equal "<title>Roda: a</title>bar"
    body('/h').delete("\n").must_equal "<title>Roda: a</title>bar"

    app.plugin :render, :layout_opts=>{:template=>'layout-alternative', :locals=>{:title=>'a'}}
    body.delete("\n").must_equal "<title>Alternative Layout: a</title>bar"
    body('/a').delete("\n").must_equal "bar"
    body('/f').delete("\n").must_equal "bar"
    body('/s').delete("\n").must_equal "<title>Roda: a</title>bar"
    body('/h').delete("\n").must_equal "<title>Roda: a</title>bar"
  end

  it "app :root option affects :views default" do
    app
    app.plugin :render
    app.render_opts[:views].must_equal File.join(Dir.pwd, 'views')

    app.opts[:root] = '/foo'
    app.plugin :render
    # Work around for Windows
    app.render_opts[:views].sub(/\A\w:/, '').must_equal '/foo/views'

    app.opts[:root] = '/foo/bar'
    app.plugin :render
    app.render_opts[:views].sub(/\A\w:/, '').must_equal '/foo/bar/views'

    app.opts[:root] = nil
    app.plugin :render
    app.render_opts[:views].must_equal File.join(Dir.pwd, 'views')
    app.plugin :render, :views=>'bar'
    app.render_opts[:views].must_equal File.join(Dir.pwd, 'bar')
  end

  if Roda::RodaPlugins::Render::COMPILED_METHOD_SUPPORT
    [true, false].each do |cache_plugin_option|
      multiplier = cache_plugin_option ? 1 : 2
      it "does not cache template renders when using a template library that doesn't support it with plugin option :cache=>#{cache_plugin_option}" do
        begin
          require 'tilt/rdoc'
        rescue
          next
        end

        app(:bare) do
          plugin :render, :views=>'spec/views', :engine=>'rdoc', :cache=>cache_plugin_option
          route do |_|
            render('a')
          end
        end

        app.render_opts[:template_method_cache]['a'].must_be_nil
        body.strip.must_equal "<p># a # * b</p>"
        app.render_opts[:template_method_cache]['a'].must_equal false
        body.strip.must_equal "<p># a # * b</p>"
        app.render_opts[:template_method_cache]['a'].must_equal false
        body.strip.must_equal "<p># a # * b</p>"
        app.render_opts[:template_method_cache]['a'].must_equal false
        app::RodaCompiledTemplates.private_instance_methods.length.must_equal 0
      end

      it "raises an exception and does not cache if trying to render a directory with :cache=>#{cache_plugin_option}" do
        app(:bare) do
          plugin :render, :views=>'spec', :cache=>cache_plugin_option
          route do |_|
            render('views')
          end
        end

        app.render_opts[:template_method_cache]['views'].must_be_nil
        proc{body}.must_raise SystemCallError
        app.render_opts[:template_method_cache]['views'].must_be_nil
      end

      ['comp_test', :comp_test].each do |template|
        it "does not cache template renders when given a hash with #{template.class} value with plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            plugin :render, :views=>'spec/views', :cache=>cache_plugin_option
            route do |_|
              render(:template=>template)
            end
          end

          app.render_opts[:template_method_cache][template].must_be_nil
          body.strip.must_equal "ct"
          app.render_opts[:template_method_cache][template].must_be_nil
          body.strip.must_equal "ct"
          app.render_opts[:template_method_cache][template].must_be_nil
          body.strip.must_equal "ct"
          app.render_opts[:template_method_cache][template].must_be_nil
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal 0
        end

        it "caches template renders when given a #{template.class} with plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            plugin :render, :views=>'spec/views', :cache=>cache_plugin_option
            route do |_|
              render(template)
            end
          end

          app.render_opts[:template_method_cache][template].must_be_nil
          body.strip.must_equal "ct"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          body.strip.must_equal "ct"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          body.strip.must_equal "ct"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal multiplier
        end

        it "does not cache template renders when there is no template method cache with plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            plugin :render, :views=>'spec/views', :cache=>cache_plugin_option
            route do |_|
              render(template)
            end
          end

          app.opts[:render] = app.opts[:render].dup
          app.opts[:render].delete(:template_method_cache)
          3.times do
            body.strip.must_equal "ct"
          end
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal 0
        end

        it "does not cache template renders with locals when there is no template method cache with plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            plugin :render, :views=>'spec/views', :cache=>cache_plugin_option
            route do |_|
              render(template, :locals => {:a=>1})
            end
          end

          app.opts[:render] = app.opts[:render].dup
          app.opts[:render].delete(:template_method_cache)
          3.times do
            body.strip.must_equal "ct"
          end
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal 0
        end

        it "does not cache template views or layout when given a hash with #{template.class} value with plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            layout = template.to_s.sub('test', 'layout')
            layout = layout.to_sym if template.is_a?(Symbol)
            plugin :render, :views=>'spec/views', :layout=>layout, :cache=>cache_plugin_option
            route do |_|
              view(:template=>template)
            end
          end

          app.render_opts[:template_method_cache][template].must_be_nil
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_nil
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_nil
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_nil
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal 0
        end

        it "caches template views with layout when given a #{template.class} with plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            layout = template.to_s.sub('test', 'layout')
            layout = layout.to_sym if template.is_a?(Symbol)
            plugin :render, :views=>'spec/views', :layout=>layout, :cache=>cache_plugin_option
            route do |_|
              view(template)
            end
          end

          app.render_opts[:template_method_cache][template].must_be_nil
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_kind_of(Array)
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_kind_of(Array)
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal(2*multiplier)
        end

        it "caches layout template automatically when freezeing when given a #{template.class} with plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            layout = template.to_s.sub('test', 'layout')
            layout = layout.to_sym if template.is_a?(Symbol)
            plugin :render, :views=>'spec/views', :layout=>layout, :cache=>cache_plugin_option
            route do |_|
              view(template)
            end
          end

          app.render_opts[:template_method_cache][template].must_be_nil
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil

          app.freeze

          app.render_opts[:template_method_cache][template].must_be_nil
          app.render_opts[:template_method_cache][:_roda_layout].must_be_kind_of(Array)
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_kind_of(Array)
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_kind_of(Array)
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_kind_of(Array)
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal(2*multiplier)
        end

        it "caches template views with inline layout when given a #{template.class} with plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            plugin :render, :views=>'spec/views', :layout=>{:inline=>"a<%= yield %>b"}, :cache=>cache_plugin_option
            route do |_|
              view(template)
            end
          end

          app.render_opts[:template_method_cache][template].must_be_nil
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "act\nb"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal(multiplier)
        end

        it "caches template views with inline layout when given a #{template.class} with explicitly not caching layout when using plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            layout = template.to_s.sub('test', 'layout')
            layout = layout.to_sym if template.is_a?(Symbol)
            plugin :render, :views=>'spec/views', :layout=>layout, :cache=>cache_plugin_option
            route do |_|
              view(template)
            end
          end

          3.times do
            app.render_opts[:template_method_cache][:_roda_layout] = false
            body.strip.must_equal "act\nb"
            app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
            app.render_opts[:template_method_cache][:_roda_layout].must_equal false
          end
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal(multiplier)
        end

        it "caches template views without layout when additional layout options given when given a #{template.class} with plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            plugin :render, :views=>'spec/views', :layout=>nil, :cache=>cache_plugin_option
            route do |_|
              view(template)
            end
          end

          app.render_opts[:template_method_cache][template].must_be_nil
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "ct"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "ct"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "ct"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal multiplier
        end

        it "caches template views without layout when additional layout options given when given a #{template.class} with plugin option :cache=>#{cache_plugin_option}" do
          app(:bare) do
            plugin :render, :views=>'spec/views', :layout_opts=>{:locals=>{:title=>"Home"}}, :cache=>cache_plugin_option
            route do |_|
              view(template)
            end
          end

          app.render_opts[:template_method_cache][template].must_be_nil
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "<title>Roda: Home</title>\nct"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "<title>Roda: Home</title>\nct"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          body.strip.must_equal "<title>Roda: Home</title>\nct"
          app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
          app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
          app::RodaCompiledTemplates.private_instance_methods.length.must_equal multiplier
        end
      end
    end
  end

  if Roda::RodaPlugins::Render::FIXED_LOCALS_COMPILED_METHOD_SUPPORT
    [true, false].each do |cache_plugin_option|
      multiplier = cache_plugin_option ? 1 : 2

      it "support fixed locals in layout templates with plugin option :cache=>#{cache_plugin_option}" do
        template = "comp_test"

        app(:bare) do
          plugin :render, :views=>'spec/views/fixed', :layout_opts=>{:locals=>{:title=>"Home"}}, :cache=>cache_plugin_option, :template_opts=>{:extract_fixed_locals=>true}
          route do |_|
            view(template)
          end
        end

        app.render_opts[:template_method_cache][template].must_be_nil
        app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
        body.strip.must_equal "<title>Roda: Home</title>\nct"
        app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
        app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
        body.strip.must_equal "<title>Roda: Home</title>\nct"
        app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
        app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
        body.strip.must_equal "<title>Roda: Home</title>\nct"
        app.render_opts[:template_method_cache][template].must_be_kind_of(Array)
        app.render_opts[:template_method_cache][:_roda_layout].must_be_nil
        app::RodaCompiledTemplates.private_instance_methods.length.must_equal multiplier
      end

      it "support fixed locals in render templates with plugin option :cache=>#{cache_plugin_option}" do
        template = "local_test"

        app(:bare) do
          plugin :render, :views=>'spec/views/fixed', :cache=>cache_plugin_option, :template_opts=>{:extract_fixed_locals=>true}
          route do |_|
            render(template, locals: {title: 'ct'})
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
          it "caches expectedly for cache: #{cache_plugin_option}, assume_fixed_locals: #{assume_fixed_locals_option} options" do
            template = "opt_local_test"

            app(:bare) do
              plugin :render, :views=>'spec/views/fixed', :cache=>cache_plugin_option, :template_opts=>{:extract_fixed_locals=>true}, :assume_fixed_locals=>assume_fixed_locals_option, :layout=>false
              route do |r|
                r.is 'a' do
                  render(template)
                end
                render(template, locals: {title: 'ct'})
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

  it "inline layouts and inline views" do
    app(:render) do |_|
      view({:inline=>'bar'}, :layout=>{:inline=>'Foo: <%= yield %>'})
    end

    body.strip.must_equal "Foo: bar"
    app.freeze
    body.strip.must_equal "Foo: bar"
  end

  it "inline renders with opts" do
    app(:render) do |_|
      render({:inline=>'<%= bar %>'}, {:engine=>'str'})
    end

    body.strip.must_equal '<%= bar %>'
    app.freeze
    body.strip.must_equal '<%= bar %>'
  end

  it "template renders with :template opts" do
    app(:bare) do
      plugin :render, :views => "./spec/views"
      route do |_|
        render(:template=>"about", :locals=>{:title => "About Roda"})
      end
    end
    body.strip.must_equal "<h1>About Roda</h1>"
  end

  it "template renders with :template_class opts" do
    app(:render) do |_|
      @a = 1
      render(:inline=>'i#{@a}', :template_class=>::Tilt[:str])
    end
    body.must_equal "i1"
  end

  it "can specify engine-specific options via :engine_opts" do
    app(:bare) do
      plugin :render, :engine_opts=>{'a.erb'=>{:outvar=>'@a'}}
      route do |r|
        @a = nil
        r.is('a') do
          render(:inline=>'<%= @a.class.name %>', :engine=>'a.erb')
        end
        render(:inline=>'<%= @a.class.name %>')
      end
    end

    body('/a').must_equal "String"
    body.must_equal "NilClass"
  end

  it "template cache respects :template_opts" do
    c = Class.new do 
      def initialize(path, _, opts)
        @path = path
        @opts = opts
      end
      def render(*)
        "#{@path}-#{@opts[:foo]}"
      end
    end

    app(:render) do |r|
      r.is "a" do
        render(:inline=>"i", :template_class=>c, :template_opts=>{:foo=>'a'})
      end
      r.is "b" do
        render(:inline=>"i", :template_class=>c, :template_opts=>{:foo=>'b'})
      end
    end

    body('/a').must_equal "i-a"
    body('/b').must_equal "i-b"
  end

  it "template cache respects :template_block" do
    c = Class.new do 
      def initialize(path, *, &block)
        @path = path
        @block = block
      end
      def render(*)
        "#{@path}-#{@block.call}"
      end
    end 

    proca = proc{'a'}
    procb = proc{'b'}

    app(:render) do |r|
      r.is "a" do
        render(:path=>"i", :template_class=>c, :template_block=>proca)
      end
      r.is "b" do
        render(:path=>"i", :template_class=>c, :template_block=>procb)
      end
    end

    body('/a').must_equal "i-a"
    body('/b').must_equal "i-b"
  end

  it "template cache respects :locals" do
    template = '<%= @a ? b : c %>'

    app(:render) do |r|
      r.is "a" do
        @a = true
        render(:inline=>template.dup, :locals=>{:b=>1})
      end
      r.is "b" do
        @a = true
        render(:inline=>template.dup, :locals=>{:b=>2, :c=>4})
      end
      r.is "c" do
        @a = nil
        render(:inline=>template.dup, :locals=>{:c=>3})
      end
    end

    body('/a').must_equal "1"
    body('/b').must_equal "2"
    body('/c').must_equal "3"
  end

  it "Default to :check_template_mtime=>true in development mode" do
    with_rack_env('development') do
      app(:render){|_|}
    end
    app.render_opts[:check_template_mtime].must_equal true
    app(:render){|_|}
    app.render_opts[:check_template_mtime].must_equal false
  end

  it "Support :cache=>false plugin option to disable template caching by default, except :cache=>true method option is given" do
    app(:bare) do
      plugin :render, :views=>"./spec/views", :cache=>false

      route do |r|
        @a = 'a'
        r.is('a'){render('iv', :cache=>false, :cache_key=>:a)}
        r.is('b'){render('iv', :cache=>true, :cache_key=>:a)}
        render('iv', :cache_key=>:a)
      end
    end

    body('/a').strip.must_equal "a"
    app.render_opts[:cache][:a].must_be_nil
    body('/b').strip.must_equal "a"
    app.render_opts[:cache][:a].wont_be_nil
    body('/c').strip.must_equal "a"
    app.render_opts[:cache][:a].wont_be_nil
  end

  it "Support :cache=>false option to disable template caching" do
    app(:bare) do
      plugin :render, :views=>"./spec/views"

      route do |r|
        @a = 'a'
        r.is('a'){render('iv', :cache=>false)}
        render('iv')
      end
    end

    body('/a').strip.must_equal "a"
    app.render_opts[:cache][File.expand_path('spec/views/iv.erb')].must_be_nil
    body('/b').strip.must_equal "a"
    app.render_opts[:cache][File.expand_path('spec/views/iv.erb')].wont_be_nil
  end

  it "Support :cache=>false option to disable template caching even when :cache_key is given" do
    app(:bare) do
      plugin :render, :views=>"./spec/views"

      route do |r|
        @a = 'a'
        r.is('a'){render('iv', :cache=>false, :cache_key=>:foo)}
        render('iv', :cache_key=>:foo)
      end
    end

    body('/a').strip.must_equal "a"
    app.render_opts[:cache][:foo].must_be_nil
    body('/b').strip.must_equal "a"
    app.render_opts[:cache][:foo].wont_be_nil
  end

  [{}, {:cache=>true}].each do |cache_val_opts|
    [{}, {:cache_key=>:foo}].each do |cache_key_opts|
      cache_opts = cache_key_opts.merge(cache_val_opts)
      it "Support :explicit_cache plugin option with #{cache_opts} render option" do
        app(:bare) do
          plugin :render, :views=>"./spec/views", :explicit_cache=>true

          route do |r|
            @a = 'a'
            render('iv', cache_opts)
          end
        end

        body('/a').strip.must_equal "a"
        template = app.render_opts[:cache][cache_opts[:cache_key] || File.expand_path("spec/views/iv.erb")]
        template.must_be_kind_of(cache_val_opts.empty? ? Roda::RodaPlugins::Render::TemplateMtimeWrapper : Tilt::Template)
        body('/a').strip.must_equal "a"
      end
    end
  end

  it "Support :cache=>true option to enable template caching when :template_block is used" do
    c = Class.new do 
      def initialize(path, *, &block)
        @path = path
        @block = block
      end
      def render(*)
        "#{@path}-#{@block.call}"
      end
    end 

    proca = proc{'a'}

    app(:bare) do
      plugin :render, :views=>"./spec/views"

      route do |r|
        @a = 'a'
        r.is('a'){render(:path=>'iv', :template_class=>c, :template_block=>proca)}
        render(:path=>'iv', :template_class=>c, :template_block=>proca, :cache=>true)
      end
    end

    body('/a').strip.must_equal "iv-a"
    app.render_opts[:cache][['iv', c, nil, nil, proca]].must_be_nil
    body('/b').strip.must_equal "iv-a"
    app.render_opts[:cache][['iv', c, nil, nil, proca]].wont_be_nil
  end

  it "Support :cache_key option to force the key used when caching, unless :cache=>false option is used" do
    app(:bare) do
      plugin :render, :views=>"./spec/views"

      route do |r|
        @a = 'a'
        r.is('a'){render('iv', :cache_key=>:a)}
        r.is('about'){render('about', :cache_key=>:a, :cache=>false, :locals=>{:title=>'a'})}
        render('about', :cache_key=>:a)
      end
    end

    body('/a').strip.must_equal "a"
    body('/b').strip.must_equal "a"
    body('/about').strip.must_equal "<h1>a</h1>"
  end

  it "Support :scope option to override object in which to evaluate the template" do
    app(:bare) do
      plugin :render, :views=>"./spec/views"

      route do |r|
        render(:inline=>'<%= first %>-<%= last %>', :scope=>[1,2])
      end
    end

    body.must_equal "1-2"
  end

  it "should dup render_opts when subclassing" do
    c = Class.new(Roda)
    c.plugin :render, :foo=>:bar
    sc = Class.new(c)
    c.render_opts.wont_be_same_as(sc.render_opts)
    c.render_opts[:foo].must_equal :bar
  end

  it "should use a copy of superclass's cache when subclassing" do
    c = Class.new(Roda)
    c.plugin :render
    c.render_opts[:cache][:foo] = 1
    sc = Class.new(c)

    c.render_opts.wont_be_same_as(sc.render_opts)
    c.render_opts[:cache].wont_be_same_as(sc.render_opts[:cache])
    sc.render_opts[:cache][:foo].must_equal 1
  end

  it "should not modifying existing cache if loading the plugin a separate time" do
    c = Class.new(Roda)
    c.plugin :render
    cache = c.render_opts[:cache]
    c.render_opts[:check_template_mtime].must_equal false
    c.plugin :render
    c.render_opts[:cache].must_be_same_as cache
    c.render_opts[:check_template_mtime].must_equal false

    c.plugin :render, :cache=>false
    c.render_opts[:cache].must_be_same_as cache
    c.render_opts[:check_template_mtime].must_equal true
    c.plugin :render
    c.render_opts[:cache].must_be_same_as cache
    c.render_opts[:check_template_mtime].must_equal true
  end

  it "render plugin call should not override existing options" do
    c = Class.new(Roda)
    c.plugin :render, :layout_opts=>{:template=>'foo'}
    c.plugin :render
    c.render_opts[:layout_opts][:template].must_equal 'foo'
  end

  it "should not use cache by default in subclass if not caching by default in superclass" do
    app(:bare) do
      plugin :render, :views=>"./spec/views", :cache=>false
      
      route do |r|
        view(:inline=>"Hello <%= name %>", :cache_key=>:a, :locals=>{:name => "Agent Smith"}, :layout=>nil)
      end
    end

    body("/inline").strip.must_equal "Hello Agent Smith"
    Class.new(app).render_opts[:check_template_mtime].must_equal true
  end

  it "with :check_paths=>true plugin option used" do
    render_opts = {}
    app(:bare) do
      plugin :render, :views=>"./spec/views", :check_paths=>true
      
      route do |r|
        r.get 'a' do
          render("a", render_opts)
        end

        r.get 'c' do
          render("about/_test", :locals=>{:title=>'a'})
        end

        render("b", render_opts)
      end
    end

    body.strip.must_equal "b"
    req("/a")
    req("/c")

    @app = Class.new(app)
    app.plugin :render, :allowed_paths=>[]
    proc{req}.must_raise Roda::RodaError
    proc{req("/a")}.must_raise Roda::RodaError
    proc{req("/c")}.must_raise Roda::RodaError

    @app = Class.new(app)
    app.plugin :render, :allowed_paths=>['spec/views/about']
    proc{req}.must_raise Roda::RodaError
    proc{req("/a")}.must_raise Roda::RodaError
    req("/c")

    @app = Class.new(app)
    app.plugin :render, :allowed_paths=>%w'spec/views/about spec/views/b'
    body.strip.must_equal "b"
    proc{req("/a")}.must_raise Roda::RodaError
    req("/c")

    render_opts[:check_paths] = true
    @app = Class.new(app)
    app.plugin :render, :check_paths=>false
    body.strip.must_equal "b"
    proc{req("/a")}.must_raise Roda::RodaError
    req("/c")

    render_opts.delete(:check_paths)
    app.plugin :render
    body.strip.must_equal "b"
    req("/a")
    req("/c")

    render_opts[:check_paths] = true
    body.strip.must_equal "b"
    proc{req("/a")}.must_raise Roda::RodaError
    req("/c")
  end

  it "with a cache_class set" do
    app(:bare) do
      test_cache = Class.new(Roda::RodaCache) do
        def [](key)
          super
        end
        def []=(key, value)
          super
        end
        def test_method
        end
      end

      plugin :render, :views=>"./spec/views", :cache=>true, :cache_class=>test_cache

      route do |r|
        view(:inline=>"foo", :layout=>nil)
      end
    end

    body("/inline").strip.must_equal "foo"

    Class.new(app).render_opts[:cache].must_respond_to :test_method
  end

  it "supports template_opts default_encoding option" do
    app(:bare){}
    app.plugin :render
    app.render_opts[:template_opts][:default_encoding].must_equal Encoding.default_external
    app.plugin :render, :template_opts=>{:default_encoding=>'ISO-8859-1'}
    app.render_opts[:template_opts][:default_encoding].must_equal 'ISO-8859-1'
  end
end
end

begin
  require 'tilt'
  require 'tilt/erubi'
rescue LoadError
  warn "tilt 2 or erubi not installed, skipping render :escape=>true test"  
else
describe ":render plugin :escape option" do
  before do
    if defined?(Tilt::ErubiTemplate) && ::Tilt['erb'] != Tilt::ErubiTemplate
      # Set erubi as default erb template handler
      Tilt.register(Tilt::ErubiTemplate, 'erb')
    end
  end

  it "should escape inside <%= %> and not inside <%== %>, and handle postfix conditionals" do
    app(:bare) do
      plugin :render, :escape=>true

      route do |r|
        render(:inline=>'<%= "<>" %> <%== "<>" %><%= "<>" if false %>')
      end
    end

    body.must_equal '&lt;&gt; <>'
  end

  it "should allow for per-branch escaping via set_view options" do
    app(:bare) do
      plugin :render, :escape=>true
      plugin :view_options

      route do |r|
        set_view_options :template_opts=>{:escape=>false}
        r.is 'a' do
          set_view_options :template_opts=>{:engine_class=>render_opts[:template_opts][:engine_class]}
          render(:inline=>'<%= "<>" %>')
        end
        render(:inline=>'<%= "<>" %>')
      end
    end

    body('/a').must_equal '&lt;&gt;'
    body.must_equal '<>'
  end

  it "should accept :escape=>String to only escape for that template engine" do
    app(:bare) do
      plugin :render, :escape=>'erb'

      route do |r|
        r.is 'a' do
          render(:inline=>'<%= "<>" %> <%== "<>" %><%= "<>" if false %>', :engine=>'unescaped.erb')
        end
        render(:inline=>'<%= "<>" %> <%== "<>" %><%= "<>" if false %>')
      end
    end

    body.must_equal '&lt;&gt; <>'
    body('/a').must_equal '<> &lt;&gt;'
  end

  it "should accept :escape=>Array to only escape for those template engines" do
    app(:bare) do
      plugin :render, :escape=>%w'erb erubi', :engine_opts=>{'erubi'=>{:bufvar=>'_buf'}}

      route do |r|
        r.is 'a' do
          render(:inline=>'<%= "<>" %> <%== "<>" %><%= "<>" if false %>', :engine=>'unescaped.erb')
        end
        r.is 'b' do
          render(:inline=>'<%= _buf.length %><%= "<>" %> <%== "<>" %><%= "<>" if false %>', :engine=>'erubi')
        end
        render(:inline=>'<%= "<>" %> <%== "<>" %><%= "<>" if false %>')
      end
    end

    body.must_equal '&lt;&gt; <>'
    body('/a').must_equal '<> &lt;&gt;'
    body('/b').must_equal '0&lt;&gt; <>'
  end
end
end
