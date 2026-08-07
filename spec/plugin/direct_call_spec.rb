require_relative "../spec_helper"

describe "direct_call plugin" do
  it "should have .call skip middleware" do
    app{|_| '123'}
    app.use(Class.new do
      def initialize(_) end
      def call(env) [200, {}, ['321']] end
    end)
    body.must_equal '321'
    app.plugin :direct_call
    body.must_equal '123'
  end

  deprecated "should work when #call is overridden" do
    app.class_eval do
      def call; super end
      route{'123'}
    end
    app.use(Class.new do
      def initialize(_) end
      def call(env) [200, {}, ['321']] end
    end)
    body.must_equal '321'
    app.plugin :direct_call
    body.must_equal '123'
  end
end
