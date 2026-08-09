require_relative "../spec_helper"

describe "delay_build plugin" do
  deprecated "does not build rack app until app is called" do
    app(:delay_build){|_| "a"}
    app.instance_variable_get(:@app).must_be_nil
    body.must_equal "a"
    # Work around minitest bug
    refute_equal app.instance_variable_get(:@app), nil
  end

  deprecated "supports the build! method for backwards compatibility" do
    app(:delay_build){|_| "a"}
    body.must_equal "a"
    c = Class.new do
      def initialize(_) end
      def call(_) [200, {}, ["b"]] end
    end
    app.use c
    app.build!
    body.must_equal "b"
  end
end
