require_relative "../spec_helper"

describe "middleware_stack plugin" do 
  it "adds middleware_stack method for removing and inserting into middleware stack" do
    make_middleware = lambda do |name|
      Class.new do
        define_singleton_method(:name){name}

        attr_reader :app
        attr_reader :args
        attr_reader :block
        def initialize(app, *args, &block)
          @app = app
          @args = args
          @block = block
        end

        def call(env)
          (env['rack.record'] ||= []) << [self.class.name, args, block]
          app.call(env)
        end
      end
    end

    recorded = nil

    app(:middleware_stack) do |r|
      recorded = env['rack.record']
      nil 
    end

    status.must_equal 404
    recorded.must_be_nil

    called = false
    app.middleware_stack.before{called = true}.use(make_middleware[:m1], :a1).must_be_nil
    unless_lint do
      called.must_equal false
    end

    status.must_equal 404
    recorded.must_equal [[:m1, [:a1], nil]]

    app.middleware_stack.before{|m, *a| m.name == :m1}.use(make_middleware[:m2]).must_be_nil

    status.must_equal 404
    recorded.must_equal [[:m2, [], nil], [:m1, [:a1], nil]]

    b = lambda{}
    app.middleware_stack.before{|m, *a| m.name == :m1}.use(make_middleware[:m3], :a2, :a3, &b).must_be_nil

    status.must_equal 404
    recorded.must_equal [[:m2, [], nil], [:m3, [:a2, :a3], b], [:m1, [:a1], nil]]

    app.middleware_stack.after{|m, *a| m.name == :m4}.use(make_middleware[:m4]).must_be_nil
    status.must_equal 404
    recorded.must_equal [[:m2, [], nil], [:m3, [:a2, :a3], b], [:m1, [:a1], nil], [:m4, [], nil]]

    app.middleware_stack.after{|m, *a| m.name == :m4}.use(make_middleware[:m5]).must_be_nil
    status.must_equal 404
    recorded.must_equal [[:m2, [], nil], [:m3, [:a2, :a3], b], [:m1, [:a1], nil], [:m4, [], nil], [:m5, [], nil]]

    app.middleware_stack.after{|m, *a| a == [:a1]}.use(make_middleware[:m6]).must_be_nil
    status.must_equal 404
    recorded.must_equal [[:m2, [], nil], [:m3, [:a2, :a3], b], [:m1, [:a1], nil], [:m6, [], nil], [:m4, [], nil], [:m5, [], nil]]

    app.middleware_stack.remove{|m, *a| a.empty?}.must_be_nil
    status.must_equal 404
    recorded.must_equal [[:m3, [:a2, :a3], b], [:m1, [:a1], nil]]

    sp = app.middleware_stack.after{|m, *a| m.name == :m3}
    sp.use(make_middleware[:m7])
    sp.use(make_middleware[:m8])
    status.must_equal 404
    recorded.must_equal [[:m3, [:a2, :a3], b], [:m8, [], nil], [:m7, [], nil], [:m1, [:a1], nil]]

    sp = app.middleware_stack.before{|m, *a| m.name == :m8}
    sp.use(make_middleware[:m9])
    sp.use(make_middleware[:m10])
    status.must_equal 404
    recorded.must_equal [[:m3, [:a2, :a3], b], [:m9, [], nil], [:m10, [], nil], [:m8, [], nil], [:m7, [], nil], [:m1, [:a1], nil]]

    app.middleware_stack.remove{true}.must_be_nil
    sp.use(make_middleware[:m10])
    status.must_equal 404
    recorded.must_equal [[:m10, [], nil]]
  end
end
