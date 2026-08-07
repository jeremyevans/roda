require_relative "../spec_helper"

begin
  require 'tilt/erb'
rescue LoadError
  warn "tilt not installed, skipping view_options plugin test"  
else
describe "view_options plugin view subdirs" do
  before do
    app(:bare) do
      plugin :render, :views=>"."
      plugin :view_options

      route do |r|
        r.on "default" do
          render("spec/views/comp_test")
        end

        append_view_subdir 'spec' 

        r.on "home" do
          set_view_subdir 'spec/views'
          view("home", :locals=>{:name => "Agent Smith", :title => "Home"}, :layout_opts=>{:locals=>{:title=>"Home"}})
        end

        r.on "about" do
          append_view_subdir 'views'
          r.on 'test' do
            append_view_subdir 'about'
            r.is('view'){view("comp_test")}
            r.is{render("comp_test")}
          end
          render("about", :locals=>{:title => "About Roda"})
        end

        r.on "path" do
          render('spec/views/about', :locals=>{:title => "Path"}, :layout_opts=>{:locals=>{:title=>"Home"}})
        end

        r.on 'test' do
          set_view_subdir 'spec/views'
          r.is('view'){view("comp_test")}
          r.is{render("comp_test")}
        end
      end
    end
  end

  it "should use set subdir if template name does not contain a slash" do
    body("/home").strip.must_equal "<title>Roda: Home</title>\n<h1>Home</h1>\n<p>Hello Agent Smith</p>"
  end

  it "should not use set subdir if template name contains a slash" do
    body("/about").strip.must_equal "<h1>About Roda</h1>"
  end

  it "should not change behavior when subdir is not set" do
    body("/path").strip.must_equal "<h1>Path</h1>"
  end

  it "should not affect behavior if methods not called during routing" do
    3.times do
      body("/default").strip.must_equal "ct"
    end
  end

  it "should handle template compilation correctly" do
    @app.plugin :render, :layout=>'./spec/views/comp_layout'
    3.times do
      body("/test").strip.must_equal "ct"
      body("/about/test").strip.must_equal "about-ct"
      body("/test/view").strip.must_equal "act\nb"
      body("/about/test/view").strip.must_equal "aabout-ct\nb"
    end
    if Roda::RodaPlugins::Render::COMPILED_METHOD_SUPPORT
      method_cache = @app.opts[:render][:template_method_cache]
      method_cache[['spec/views', 'comp_test']].must_be_kind_of(Array)
      method_cache[['spec/views/about', 'comp_test']].must_be_kind_of(Array)
      method_cache[:_roda_layout].must_be_kind_of(Array)
    end
  end
end

describe "view_options plugin" do
  it "should not use :views view option for layout" do
    app(:bare) do
      plugin :render, :views=>'spec/views', :allowed_paths=>['spec/views']
      plugin :view_options

      route do |_|
        set_view_options :views=>'spec/views/about'
        set_layout_options :template=>'layout-alternative'
        view('_test', :locals=>{:title=>'About Roda'}, :layout_opts=>{:locals=>{:title=>'Home'}})
      end
    end

    body.strip.must_equal "<title>Alternative Layout: Home</title>\n<h1>Subdir: About Roda</h1>"
  end

  it "should skip template compilation when only :locals key is given when using view options" do
    app(:bare) do
      plugin :render, :views=>'spec/views', :allowed_paths=>['spec/views']
      plugin :view_options

      route do |_|
        set_view_options :views=>'spec/views/about'
        render('_test', :locals=>{:title=>'About Roda'})
      end
    end

    3.times do
      body.strip.must_equal "<h1>Subdir: About Roda</h1>"
    end
  end

  it "should allow overriding :layout plugin option with set_layout_options :template" do
    app(:bare) do
      plugin :render, :views=>'spec/views', :allowed_paths=>['spec/views']
      plugin :view_options

      route do |_|
        set_view_options :views=>'spec/views/about'
        set_layout_options :template=>'layout-alternative'
        view('_test', :locals=>{:title=>'About Roda'}, :layout_opts=>{:locals=>{:title=>'Home'}})
      end
    end

    body.strip.must_equal "<title>Alternative Layout: Home</title>\n<h1>Subdir: About Roda</h1>"
  end

  it "should allow overriding :layout_opts :template plugin option with set_layout_options :template" do
    app(:bare) do
      plugin :render, :views=>'spec/views', :allowed_paths=>['spec/views'], :layout_opts=>{:template=>'layout'}
      plugin :view_options

      route do |_|
        set_view_options :views=>'spec/views/about', :layout=>'layout-alternative'
        set_layout_options :template=>'layout-alternative'
        view('_test', :locals=>{:title=>'About Roda'}, :layout_opts=>{:locals=>{:title=>'Home'}})
      end
    end

    body.strip.must_equal "<title>Alternative Layout: Home</title>\n<h1>Subdir: About Roda</h1>"
  end

  it "should allow overriding :layout plugin option with set_view_options :layout" do
    app(:bare) do
      plugin :render, :views=>'spec/views', :allowed_paths=>['spec/views'], :layout=>'layout'
      plugin :view_options

      route do |_|
        set_view_options :views=>'spec/views/about', :layout=>'layout-alternative'
        view('_test', :locals=>{:title=>'About Roda'}, :layout_opts=>{:locals=>{:title=>'Home'}})
      end
    end

    body.strip.must_equal "<title>Alternative Layout: Home</title>\n<h1>Subdir: About Roda</h1>"
  end

  it "should set view and layout options to use" do
    app(:bare) do
      plugin :render, :allowed_paths=>['spec/views']
      plugin :view_options
      plugin :render_locals, :render=>{:title=>'About Roda'}, :layout=>{:title=>'Home'}

      route do |_|
        set_view_options :views=>'spec/views'
        set_layout_options :views=>'spec/views', :template=>'layout-alternative'
        view('about')
      end
    end

    body.strip.must_equal "<title>Alternative Layout: Home</title>\n<h1>About Roda</h1>"
  end

  it "should merge multiple calls to set view and layout options" do
    app(:bare) do
      plugin :render, :allowed_paths=>['spec/views']
      plugin :view_options
      plugin :render_locals, :render=>{:title=>'Home', :b=>'B'}, :layout=>{:title=>'About Roda', :a=>'A'}

      route do |_|
        set_layout_options :views=>'spec/views', :template=>'multiple-layout', :engine=>'str'
        set_view_options :views=>'spec/views', :engine=>'str'

        set_layout_options :engine=>'erb'
        set_view_options :engine=>'erb'

        view('multiple')
      end
    end

    body.strip.must_equal "About Roda:A::Home:B"
  end
end
end
