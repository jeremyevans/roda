require_relative "../spec_helper"

begin
  require 'tilt'
rescue LoadError
  warn "tilt not installed, skipping capture_erb plugin test"
else
describe "capture_erb plugin" do
  before do
    app(:bare) do
      plugin :render, :views => './spec/views'
      plugin :capture_erb
      plugin :inject_erb

      route do |r|
        r.root do
          render(:inline => "<% value = capture_erb do %>foo<% end %>bar<%= value %>")
        end
        r.get "nil" do
          render(:inline => "<% value = capture_erb do %>foo<% nil end %>bar<%= value %>")
        end
        r.get "returns", String do |x|
          @x = x
          render(:inline => "<% value = capture_erb(returns: @x.to_sym) do %>foo<% nil end %>bar<%= value %>")
        end
        r.get "returns_hash", String do |x|
          @x = x
          render(:inline => "<% value = capture_erb({returns: @x.to_sym}) do %>foo<% nil end %>bar<%= value %>")
        end
        r.get 'rescue' do
          render(:inline => "<% value = capture_erb do %>foo<% raise %><% end rescue (value = 'baz') %>bar<%= value %>")
        end
        r.get 'inject' do
          render(:inline => "<% some_method do %>foo<% end %>")
        end
        r.get 'monkey-patch' do
          render(:inline => "<% def (instance_variable_get(render_opts[:template_opts][:outvar])).capture(x); end ; value = capture_erb do %>foo<% end %>bar<%= value %>")
        end
        r.get 'outside' do
          capture_erb{1}
        end
      end

      def some_method(&block)
        inject_erb "bar"
        inject_erb capture_erb(&block).upcase
        inject_erb "baz"
      end
    end
  end

  it "should capture erb output" do
    body.strip.must_equal "barfoo"
  end

  it "should return block value by default" do
    body("/nil").strip.must_equal "bar"
  end

  it "should return buffer value if returns: :buffer plugin argument is given" do
    app.plugin :capture_erb, returns: :buffer
    body("/nil").strip.must_equal "barfoo"
  end

  deprecated "should return buffer value if returns: :buffer plugin option is given" do
    app.plugin :capture_erb, {returns: :buffer}
    body("/nil").strip.must_equal "barfoo"
  end

  it "should return buffer value if returns: :buffer method argument is given" do
    body("/returns/other").strip.must_equal "bar"
    body("/returns/buffer").strip.must_equal "barfoo"
    app.plugin :capture_erb, returns: :buffer
    body("/returns/other").strip.must_equal "bar"
    body("/returns/buffer").strip.must_equal "barfoo"
  end

  deprecated "should return buffer value if returns: :buffer method option is given" do
    body("/returns_hash/other").strip.must_equal "bar"
    body("/returns_hash/buffer").strip.must_equal "barfoo"
    app.plugin :capture_erb, returns: :buffer
    body("/returns_hash/other").strip.must_equal "bar"
    body("/returns_hash/buffer").strip.must_equal "barfoo"
  end

  it "should handle exceptions in captured blocks" do
    body('/rescue').strip.must_equal "barbaz"
  end

  it "should work with the inject_erb plugin" do
    body('/inject').strip.must_equal "barFOObaz"
  end

  it "should work if buffer String instance defines capture" do
    body('/monkey-patch').must_equal "barfoo"
  end

  it "should return result of block converted to string when used outside template" do
    body('/outside').must_equal "1"
  end
end
end

begin
  require 'tilt/erubi'
  require 'erubi/capture_block'
rescue LoadError
  warn "tilt/erubi or erubi/capture not installed, skipping capture_erb plugin test for erubi/capture_block"
else
describe "capture_erb plugin with erubi/capture_block" do
  before do
    app(:bare) do
      plugin :render, :views => './spec/views', template_opts: {engine_class: Erubi::CaptureBlockEngine}
      plugin :capture_erb
      plugin :inject_erb

      route do |r|
        r.root do
          render(:inline => "<% value = capture_erb do %>foo<% end %>bar<%= value %>")
        end
        r.get "nil" do
          render(:inline => "<% value = capture_erb do %>foo<% nil end %>bar<%= value %>")
        end
        r.get "returns", String do |x|
          @x = x
          render(:inline => "<% value = capture_erb(returns: @x.to_sym) do %>foo<% nil end %>bar<%= value %>")
        end
        r.get 'rescue' do
          render(:inline => "<% value = capture_erb do %>foo<% raise %><% end rescue (value = 'baz') %>bar<%= value %>")
        end
        r.get 'inject' do
          render(:inline => "<%= some_method do %>foo<% end %>")
        end
        r.get 'outside' do
          capture_erb{1}
        end
      end

      def some_method(&block)
        "bar#{capture_erb(&block).upcase}baz"
      end
    end
  end

  it "should capture erb output" do
    body.strip.must_equal "barfoo"
  end

  it "should return buffer value always" do
    body("/nil").strip.must_equal "barfoo"
    body("/returns/other").strip.must_equal "barfoo"
    body("/returns/buffer").strip.must_equal "barfoo"
  end

  it "should handle exceptions in captured blocks" do
    body('/rescue').strip.must_equal "barbaz"
  end

  it "should work with the inject_erb plugin" do
    body('/inject').strip.must_equal "barFOObaz"
  end

  it "should return result of block converted to string when used outside template" do
    body('/outside').must_equal "1"
  end
end
end
