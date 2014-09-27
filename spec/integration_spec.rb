require File.expand_path("spec_helper", File.dirname(__FILE__))

describe "integration" do 
  before do
    @c = Class.new do
      def initialize(app, first, second, &block)
        @app, @first, @second, @block = app, first, second, block
      end

      def call(env)
        env["m.first"] = @first
        env["m.second"] = @second
        env["m.block"] = @block.call

        @app.call(env)
      end
    end

  end

  it "should setup middleware using use" do
    c = @c
    app(:bare) do 
      use c, "First", "Second" do
        "Block"
      end

      route do |r|
        r.get "hello" do
          "D #{r.env['m.first']} #{r.env['m.second']} #{r.env['m.block']}"
        end
      end
    end

    body('/hello').should == 'D First Second Block'
  end

  it "should support adding middleware using use after route block setup" do
    c = @c
    app(:bare) do 
      route do |r|
        r.get "hello" do
          "D #{r.env['m.first']} #{r.env['m.second']} #{r.env['m.block']}"
        end
      end

      use c, "First", "Second" do
        "Block"
      end
    end

    body('/hello').should == 'D First Second Block'
  end

  it "should inherit middleware in subclass" do
    c = @c
    @app = Class.new(app(:bare){use(c, '1', '2'){"3"}})
    @app.route do  |r|
      r.get "hello" do
        "D #{r.env['m.first']} #{r.env['m.second']} #{r.env['m.block']}"
      end
    end

    body('/hello').should == 'D 1 2 3'
  end

  it "should inherit route in subclass" do
    c = @c
    app(:bare) do
      use(c, '1', '2'){"3"}
      route do |r|
        r.get "hello" do
          "D #{r.env['m.first']} #{r.env['m.second']} #{r.env['m.block']}"
        end
      end
    end
    @app = Class.new(app)

    body('/hello').should == 'D 1 2 3'
  end

  it "should use instance of subclass when inheriting routes" do
    c = @c
    obj = nil
    app(:bare) do
      use(c, '1', '2'){"3"}
      route do |r|
        r.get "hello" do
          obj = self
          "D #{r.env['m.first']} #{r.env['m.second']} #{r.env['m.block']}"
        end
      end
    end
    @app = Class.new(app)

    body('/hello').should == 'D 1 2 3'
    obj.should be_a_kind_of(@app)
  end

  it "should handle middleware added to subclass using superclass route" do
    c = @c
    app(:bare) do
      route do |r|
        r.get "hello" do
          "D #{r.env['m.first']} #{r.env['m.second']} #{r.env['m.block']}"
        end
      end
    end
    @app = Class.new(app)
    @app.use(c, '1', '2'){"3"}

    body('/hello').should == 'D 1 2 3'
  end

  it "should not have future middleware additions to superclass affect subclass" do
    c = @c
    a = app
    @app = Class.new(a)
    @app.route do  |r|
      r.get "hello" do
        "D #{r.env['m.first']} #{r.env['m.second']} #{r.env['m.block']}"
      end
    end
    a.use(c, '1', '2'){"3"}

    body('/hello').should == 'D   '
  end

  it "should not have future middleware additions to subclass affect superclass" do
    c = @c
    a = app do |r|
      r.get "hello" do
        "D #{r.env['m.first']} #{r.env['m.second']} #{r.env['m.block']}"
      end
    end
    @app = Class.new(a)
    @app.use(c, '1', '2'){"3"}
    @app = a

    body('/hello').should == 'D   '
  end

  it "should have app return the rack application to call" do
    app(:bare){}.app.should == nil
    app.route{|r|}
    app.app.should be_a_kind_of(Proc)
    c = Class.new{def initialize(app) @app = app end; def call(env) @app.call(env) end} 
    app.use c
    app.app.should be_a_kind_of(c)
  end

  it "should have route_block return the route block" do
    app{|r| 1}.route_block.call(nil).should == 1
  end
end
