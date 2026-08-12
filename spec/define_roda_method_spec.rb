require_relative "spec_helper"

describe "Roda.define_roda_method" do
  before do
    @scope = app.new({'PATH_INFO'=>'/'})
  end

  it "should define methods using block" do
    m0 = app.define_roda_method("x", 0){1}
    m0.must_be_kind_of Symbol
    m0.must_match(/\A_roda_x_\d+\z/)
    @scope.send(m0).must_equal 1

    m1 = app.define_roda_method("x", 1){|x| [x, 2]}
    m1.must_be_kind_of Symbol
    m1.must_match(/\A_roda_x_\d+\z/)
    @scope.send(m1, 3).must_equal [3, 2]
  end

  it "should define private methods" do
    proc{@scope.public_send(app.define_roda_method("x", 0){1})}.must_raise NoMethodError
  end

  it "should accept symbols as method name and return the same symbol" do
    m0 = app.define_roda_method(:_roda_foo, 0){1}
    m0.must_equal :_roda_foo
    @scope.send(m0).must_equal 1
  end

  it "should handle optional arguments and splats for expected_arity 0" do
    m2 = app.define_roda_method("x", 0){|*x| [x, 3]}
    @scope.send(m2).must_equal [[], 3]

    m3 = app.define_roda_method("x", 0){|x=5| [x, 4]}
    @scope.send(m3).must_equal [5, 4]

    m4 = app.define_roda_method("x", 0){|x=6, *y| [x, y, 5]}
    @scope.send(m4).must_equal [6, [], 5]
  end

  it "should should optional arguments and splats for expected_arity 1" do
    m2 = app.define_roda_method("x", 1){|y, *x| [y, x, 3]}
    @scope.send(m2, :a).must_equal [:a, [], 3]

    m3 = app.define_roda_method("x", 1){|y, x=5| [y, x, 4]}
    @scope.send(m3, :b).must_equal [:b, 5, 4]

    m4 = app.define_roda_method("x", 1){|y, x=6, *z| [y, x, z, 5]}
    @scope.send(m4, :c).must_equal [:c, 6, [], 5]
  end

  deprecated "should handle differences in arity" do
    m0 = app.define_roda_method("x", 0){|x| [x, 1]}
    @scope.send(m0).must_equal [nil, 1]

    m1 = app.define_roda_method("x", 1){2}
    @scope.send(m1, 3).must_equal 2

    m1 = app.define_roda_method("x", 1){|x, y| [x, y]}
    @scope.send(m1, 4).must_equal [4, nil]
  end

  it "should raise for unexpected expected_arity" do
    proc{app.define_roda_method("x", 2){|x|}}.must_raise Roda::RodaError
  end

  it "should fail if :check_arity false app option is used and a block with invalid arity is passed" do
    app.opts[:check_arity] = false
    m0 = app.define_roda_method("x", 0){|x| [x, 1]}
    proc{@scope.send(m0)}.must_raise ArgumentError

    m1 = app.define_roda_method("x", 1){2}
    proc{@scope.send(m1, 1)}.must_raise ArgumentError

    m1 = app.define_roda_method("x", 1){|x, y| [x, y]}
    proc{@scope.send(m1, 4)}.must_raise ArgumentError
  end

  [:warn, true].each do |check_arity|
    deprecated "should warn if :check_arity :warn app option is used and a block with invalid arity is passed" do
      app.opts[:check_arity] = check_arity
      m0 = app.define_roda_method("x", 0){|x| [x, 1]}
      @scope.send(m0).must_equal [nil, 1]

      m1 = app.define_roda_method("x", 1){2}
      @scope.send(m1, 3).must_equal 2

      m1 = app.define_roda_method(:"x y", 1){2}
      @scope.send(m1, 4).must_equal 2

      m1 = app.define_roda_method("x", 1){|x, y| [x, y]}
      @scope.send(m1, 4).must_equal [4, nil]
    end
  end

  [false, true].each do |warn_dynamic_arity| 
    meth = warn_dynamic_arity ? :deprecated : :it
    send meth, "should handle expected_arity :any and do dynamic arity check/fix" do
      unless warn_dynamic_arity
        app.opts[:check_dynamic_arity] = true
      end

      m0 = app.define_roda_method("x", :any){1}
      @scope.send(m0).must_equal 1
      @scope.send(m0, 2).must_equal 1

      m1 = app.define_roda_method("x", :any){|x| [x, 1]}
      @scope.send(m1).must_equal [nil, 1]
      @scope.send(m1, 2).must_equal [2, 1]
      @scope.send(m1, 2, 3).must_equal [2, 1]

      m2 = app.define_roda_method("x", :any){|x=5| [x, 2]}
      @scope.send(m2).must_equal [5, 2]
      @scope.send(m2, 2).must_equal [2, 2]
      @scope.send(m2, 2, 3).must_equal [2, 2]

      m3 = app.define_roda_method("x", :any){|y, x=5| [x, y, 3]}
      @scope.send(m3).must_equal [5, nil, 3]
      @scope.send(m3, 2).must_equal [5, 2, 3]
      @scope.send(m3, 2, 3).must_equal [3, 2, 3]
      @scope.send(m3, 2, 3, 4).must_equal [3, 2, 3]

      m4 = app.define_roda_method("x", :any){|*z| [z, 1]}
      @scope.send(m4).must_equal [[], 1]
      @scope.send(m4, 2).must_equal [[2], 1]

      m5 = app.define_roda_method("x", :any){|x, *z| [x, z, 1]}
      @scope.send(m5).must_equal [nil, [], 1]
      @scope.send(m5, 2).must_equal [2, [], 1]
      @scope.send(m5, 2, 3).must_equal [2, [3], 1]

      m6 = app.define_roda_method("x", :any){|x=5, *z| [x, z, 2]}
      @scope.send(m6).must_equal [5, [], 2]
      @scope.send(m6, 2).must_equal [2, [], 2]
      @scope.send(m6, 2, 3).must_equal [2, [3], 2]

      m7 = app.define_roda_method("x", :any){|y, x=5, *z| [x, y, z, 3]}
      @scope.send(m7).must_equal [5, nil, [], 3]
      @scope.send(m7, 2).must_equal [5, 2, [], 3]
      @scope.send(m7, 2, 3).must_equal [3, 2, [], 3]
      @scope.send(m7, 2, 3, 4).must_equal [3, 2, [4], 3]
    end
  end

  it "should not fix dynamic arity issues if :check_dynamic_arity false app option is used" do
    app.opts[:check_dynamic_arity] = false

    m0 = app.define_roda_method("x", :any){1}
    @scope.send(m0).must_equal 1
    proc{@scope.send(m0, 2)}.must_raise ArgumentError

    m1 = app.define_roda_method("x", :any){|x| [x, 1]}
    proc{@scope.send(m1)}.must_raise ArgumentError
    @scope.send(m1, 2).must_equal [2, 1]
    proc{@scope.send(m1, 2, 3)}.must_raise ArgumentError

    m2 = app.define_roda_method("x", :any){|x=5| [x, 2]}
    @scope.send(m2).must_equal [5, 2]
    @scope.send(m2, 2).must_equal [2, 2]
    proc{@scope.send(m2, 2, 3)}.must_raise ArgumentError

    m3 = app.define_roda_method("x", :any){|y, x=5| [x, y, 3]}
    proc{@scope.send(m3)}.must_raise ArgumentError
    @scope.send(m3, 2).must_equal [5, 2, 3]
    @scope.send(m3, 2, 3).must_equal [3, 2, 3]
    proc{@scope.send(m3, 2, 3, 4)}.must_raise ArgumentError

    m4 = app.define_roda_method("x", :any){|*z| [z, 1]}
    @scope.send(m4).must_equal [[], 1]
    @scope.send(m4, 2).must_equal [[2], 1]

    m5 = app.define_roda_method("x", :any){|x, *z| [x, z, 1]}
    proc{@scope.send(m5)}.must_raise ArgumentError
    @scope.send(m5, 2).must_equal [2, [], 1]
    @scope.send(m5, 2, 3).must_equal [2, [3], 1]

    m6 = app.define_roda_method("x", :any){|x=5, *z| [x, z, 2]}
    @scope.send(m6).must_equal [5, [], 2]
    @scope.send(m6, 2).must_equal [2, [], 2]
    @scope.send(m6, 2, 3).must_equal [2, [3], 2]

    m7 = app.define_roda_method("x", :any){|y, x=5, *z| [x, y, z, 3]}
    proc{@scope.send(m7)}.must_raise ArgumentError
    @scope.send(m7, 2).must_equal [5, 2, [], 3]
    @scope.send(m7, 2, 3).must_equal [3, 2, [], 3]
    @scope.send(m7, 2, 3, 4).must_equal [3, 2, [4], 3]
  end

  if RUBY_VERSION > '2.1'
    it "should raise for required keyword arguments for expected_arity 0 or 1" do
      proc{eval("app.define_roda_method('x', 0){|b:| [b, 1]}", binding)}.must_raise Roda::RodaError
      proc{eval("app.define_roda_method('x', 0){|c=1, b:| [c, b, 1]}", binding)}.must_raise Roda::RodaError
      proc{eval("app.define_roda_method('x', 1){|x, b:| [b, 1]}", binding)}.must_raise Roda::RodaError
      proc{eval("app.define_roda_method('x', 1){|x, c=1, b:| [c, b, 1]}", binding)}.must_raise Roda::RodaError
    end

    it "should ignore keyword arguments for expected_arity 0" do
      @scope.send(eval("app.define_roda_method('x', 0){|b:2| [b, 1]}", binding)).must_equal [2, 1]
      @scope.send(eval("app.define_roda_method('x', 0){|**b| [b, 1]}", binding)).must_equal [{}, 1]
      @scope.send(eval("app.define_roda_method('x', 0){|c=1, b:2| [c, b, 1]}", binding)).must_equal [1, 2, 1]
      @scope.send(eval("app.define_roda_method('x', 0){|c=1, **b| [c, b, 1]}", binding)).must_equal [1, {}, 1]
    end

    deprecated "should ignore keyword arguments for expected_arity 0" do
      @scope.send(eval("app.define_roda_method('x', 0){|x, b:2| [x, b, 1]}", binding)).must_equal [nil, 2, 1]
      @scope.send(eval("app.define_roda_method('x', 0){|x, **b| [x, b, 1]}", binding)).must_equal [nil, {}, 1]
      @scope.send(eval("app.define_roda_method('x', 0){|x, c=1, b:2| [x, c, b, 1]}", binding)).must_equal [nil, 1, 2, 1]
      @scope.send(eval("app.define_roda_method('x', 0){|x, c=1, **b| [x, c, b, 1]}", binding)).must_equal [nil, 1, {}, 1]
    end

    deprecated "should ignore keyword arguments for expected_arity 1" do
      @scope.send(eval("app.define_roda_method('x', 1){|b:2| [b, 1]}", binding), 3).must_equal [2, 1]
      @scope.send(eval("app.define_roda_method('x', 1){|**b| [b, 1]}", binding), 3).must_equal [{}, 1]
    end

    it "should ignore keyword arguments for expected_arity 1" do
      @scope.send(eval("app.define_roda_method('x', 1){|c=1, b:2| [c, b, 1]}", binding), 3).must_equal [3, 2, 1]
      @scope.send(eval("app.define_roda_method('x', 1){|c=1, **b| [c, b, 1]}", binding), 3).must_equal [3, {}, 1]
      @scope.send(eval("app.define_roda_method('x', 1){|x, b:2| [x, b, 1]}", binding), 3).must_equal [3, 2, 1]
      @scope.send(eval("app.define_roda_method('x', 1){|x, **b| [x, b, 1]}", binding), 3).must_equal [3, {}, 1]
      @scope.send(eval("app.define_roda_method('x', 1){|x, c=1, b:2| [x, c, b, 1]}", binding), 3).must_equal [3, 1, 2, 1]
      @scope.send(eval("app.define_roda_method('x', 1){|x, c=1, **b| [x, c, b, 1]}", binding), 3).must_equal [3, 1, {}, 1]
    end

    it "should handle expected_arity :any with keyword arguments" do
      if RUBY_VERSION >= '2.7' && RUBY_VERSION < '3'
        suppress = proc do |&b|
          begin
            stderr = $stderr
            $stderr = rack_input
            b.call
          ensure
            $stderr = stderr
          end
        end
      else
        suppress = proc{|&b| b.call}
      end

      m = eval('app.define_roda_method("x", :any){|b:2| b}', binding)
      @scope.send(m).must_equal 2
      @scope.send(m, 4).must_equal 2
      @scope.send(m, b: 3).must_equal 3
      @scope.send(m, 4, b: 3).must_equal 3

      m = eval('app.define_roda_method("x", :any){|b:| b}', binding)
      proc{@scope.send(m)}.must_raise ArgumentError
      proc{@scope.send(m, 4)}.must_raise ArgumentError
      @scope.send(m, b: 3).must_equal 3
      @scope.send(m, 4, b: 3).must_equal 3

      m = eval('app.define_roda_method("x", :any){|**b| b}', binding)
      @scope.send(m).must_equal({})
      @scope.send(m, 4).must_equal({})
      @scope.send(m, b: 3).must_equal(b: 3)
      @scope.send(m, 4, b: 3).must_equal(b: 3)

      m = eval('app.define_roda_method("x", :any){|x, b:9| [x, b, 1]}', binding)
      suppress.call{@scope.send(m)[1..-1]}.must_equal [9, 1]
      @scope.send(m, 2).must_equal [2, 9, 1]
      @scope.send(m, 2, 3).must_equal [2, 9, 1]
      eval("@scope.send(m, {b: 4}#{', **{}' if RUBY_VERSION > '2'})").must_equal [{b: 4}, 9, 1]
      @scope.send(m, 2, b: 4).must_equal [2, 4, 1]
      @scope.send(m, 2, 3, b: 4).must_equal [2, 4, 1]

      m = eval('app.define_roda_method("x", :any){|x, b:| [x, b, 1]}', binding)
      proc{suppress.call{@scope.send(m)}}.must_raise ArgumentError
      proc{@scope.send(m, 2)}.must_raise ArgumentError
      proc{@scope.send(m, 2, 3)}.must_raise ArgumentError
      proc{eval("@scope.send(m, {b: 4}#{', **{}' if RUBY_VERSION > '2'})")}.must_raise ArgumentError
      @scope.send(m, 2, b: 4).must_equal [2, 4, 1]
      @scope.send(m, 2, 3, b: 4).must_equal [2, 4, 1]

      m = eval('app.define_roda_method("x", :any){|x, **b| [x, b, 1]}', binding)
      suppress.call{@scope.send(m)[1..-1]}.must_equal [{}, 1]
      @scope.send(m, 2).must_equal [2, {}, 1]
      @scope.send(m, 2, 3).must_equal [2, {}, 1]
      eval("@scope.send(m, {b: 4}#{', **{}' if RUBY_VERSION > '2'})").must_equal [{b: 4}, {}, 1]
      @scope.send(m, 2, b: 4).must_equal [2, {b: 4}, 1]
      @scope.send(m, 2, 3, b: 4).must_equal [2, {b: 4}, 1]

      m = eval('m = app.define_roda_method("x", :any){|x=5, b:9| [x, b, 2]}', binding)
      @scope.send(m).must_equal [5, 9, 2]
      @scope.send(m, 2).must_equal [2, 9, 2]
      @scope.send(m, 2, 3).must_equal [2, 9, 2]
      @scope.send(m, b: 4).must_equal [5, 4, 2]
      @scope.send(m, 2, b: 4).must_equal [2, 4, 2]
      @scope.send(m, 2, 3, b: 4).must_equal [2, 4, 2]
    end
  end
end
