require_relative "../spec_helper"

begin
  require 'tilt/erb'
rescue LoadError
  warn "tilt not installed, skipping branch_locals plugin test"  
else

describe "branch_locals plugin" do
  it "should set view and layout locals to use" do
    app(:branch_locals) do |_|
      set_view_locals :title=>'About Roda'
      set_layout_locals :title=>'Home'
      view(:inline=>'<h1><%= title %></h1>', :layout=>{:inline=>"<title>Alternative Layout: <%= title %></title>\n<%= yield %>"})
    end

    body.strip.must_equal "<title>Alternative Layout: Home</title>\n<h1>About Roda</h1>"
  end

  it "should have set_view_locals work without set_layout_locals" do
    app(:branch_locals) do |_|
      set_view_locals :title=>'About Roda'
      view(:inline=>'<h1><%= title %></h1>', :layout=>{:inline=>"<title>Alternative Layout: <%= title %></title>\n<%= yield %>", :locals=>{:title=>'Home'}})
    end

    body.strip.must_equal "<title>Alternative Layout: Home</title>\n<h1>About Roda</h1>"
  end

  it "should have set_layout_locals work without set_view_locals" do
    app(:branch_locals) do |_|
      set_layout_locals :title=>'Home'
      view(:inline=>'<h1><%= title %></h1>', :locals=>{:title=>'About Roda'}, :layout=>{:inline=>"<title>Alternative Layout: <%= title %></title>\n<%= yield %>"})
    end

    body.strip.must_equal "<title>Alternative Layout: Home</title>\n<h1>About Roda</h1>"
  end

  it "should merge multiple calls to set view and layout locals" do
    app(:branch_locals) do |_|
      set_layout_locals :title=>'About Roda'
      set_view_locals :title=>'Home'

      set_layout_locals :a=>'A'
      set_view_locals :b=>'B'

      view(:inline=>'<%= title %>:<%= b %>', :layout=>{:inline=>"<%= title %>:<%= a %>::<%= yield %>"})
    end

    body.strip.must_equal "About Roda:A::Home:B"
  end

  it "should merge multiple calls in the correct order" do
    app(:branch_locals) do |_|
      set_layout_locals :title=>'Roda'
      set_view_locals :title=>'H'

      set_layout_locals :a=>'A', :title=>'About Roda'
      set_view_locals :b=>'B', :title=>'Home'

      view(:inline=>'<%= title %>:<%= b %>', :layout=>{:inline=>"<%= title %>:<%= a %>::<%= yield %>"})
    end

    body.strip.must_equal "About Roda:A::Home:B"
  end

  it "should have set_view_locals have more precedence than plugin options, but less than view/render method options" do
    app(:bare) do 
      plugin :render, :views=>"./spec/views", :layout_opts=>{:template=>'multiple-layout'}
      plugin :render_locals, :render=>{:title=>'Home', :b=>'B'}, :layout=>{:title=>'About Roda', :a=>'A'}
      plugin :branch_locals

      route do |r|
        r.is 'c' do
          view(:multiple)
        end

        set_view_locals :b=>'BB'
        set_layout_locals :a=>'AA'

        r.on 'b' do
          set_view_locals :title=>'About'
          set_layout_locals :title=>'Roda'

          r.is 'a' do
            view(:multiple)
          end

          view("multiple", :locals=>{:b => "BBB"}, :layout_opts=>{:locals=>{:a=>'AAA'}})
        end

        r.is 'a' do
          view(:multiple)
        end

        view("multiple", :locals=>{:b => "BBB"}, :layout_opts=>{:locals=>{:a=>'AAA'}})
      end
    end

    body('/c').strip.must_equal "About Roda:A::Home:B"
    body('/b/a').strip.must_equal "Roda:AA::About:BB"
    body('/b').strip.must_equal "Roda:AAA::About:BBB"
    body('/a').strip.must_equal "About Roda:AA::Home:BB"
    body.strip.must_equal "About Roda:AAA::Home:BBB"
  end
end
end
