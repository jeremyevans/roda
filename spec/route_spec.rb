require_relative "spec_helper"

describe "Roda.route" do
  it "should set the route block" do
    pr = proc{|_| '123'}
    app.route(&pr)
    app.route_block.must_equal pr
    body.must_equal '123'
  end

  it "should work if called in subclass and parent class later frozen" do
    a = app
    @app = Class.new(a)
    @app.route{|r| "OK"}
    body.must_equal "OK"
    a.freeze
    body.must_equal "OK"
    app.freeze
    body.must_equal "OK"
  end

  deprecated "should support #call being overridden" do
    app.class_eval do
      def call; super end
    end
    app.route{|_| '123'}
    body.must_equal '123'
  end

  deprecated "should support #_call" do
    pr = proc{|_| env['PATH_INFO']}
    app{_call(&pr)}
    body.must_equal '/'
  end

  deprecated "should be callable without a block" do
    app.route.must_be_nil
  end
end
