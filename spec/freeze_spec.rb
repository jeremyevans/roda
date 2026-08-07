require_relative "spec_helper"

describe "Roda.freeze" do
  before do
    app{|_| 'a'}.freeze
  end

  it "should result in a working application" do
    body.must_equal 'a'
  end

  it "should not break if called more than once" do
    app.freeze
    body.must_equal 'a'
  end

  it "should make opts not be modifiable after calling finalize!" do
    proc{app.opts[:foo] = 'bar'}.must_raise
  end

  it "should make use and route raise errors" do
    proc{app.use Class.new}.must_raise
    proc{app.route{|_|}}.must_raise
  end

  it "should make plugin raise errors" do
    proc{app.plugin Module.new}.must_raise
  end

  it "should make subclassing raise errors" do
    proc{Class.new(app)}.must_raise
  end

  it "should freeze app" do
    app.frozen?.must_equal true
  end

  it "should work after adding middleware" do
    app(:bare) do
      use(Class.new do
        def initialize(app) @app = app end
        def call(env) @app.call(env) end
      end)
      route do |_|
        'a'
      end
    end

    app.freeze
    body.must_equal 'a'
  end
end
