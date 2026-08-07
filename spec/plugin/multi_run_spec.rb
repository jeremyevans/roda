require_relative "../spec_helper"

describe "multi_run plugin" do 
  it "adds Roda.run method for setting up prefix delegations to other rack apps" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    app.run "a", Class.new(Roda).class_eval{route{|_| "a1"}; app}

    body("/a").must_equal 'a1'
    body("/b").must_equal 'c'
    body("/b/a").must_equal 'c'
    body.must_equal 'c'

    app.run "b", Class.new(Roda).class_eval{route{|_| "b1"}; app}

    body("/a").must_equal 'a1'
    body("/b").must_equal 'b1'
    body("/b/a").must_equal 'b1'
    body.must_equal 'c'

    app.run "b/a", Class.new(Roda).class_eval{route{|_| "b2"}; app}

    body("/a").must_equal 'a1'
    body("/b").must_equal 'b1'
    body("/b/a").must_equal 'b2'
    body.must_equal 'c'
  end

  it "works when freezing the app" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    app.run "a", Class.new(Roda).class_eval{route{|_| "a1"}; app}
    app.run "b", Class.new(Roda).class_eval{route{|_| "b1"}; app}
    app.run "b/a", Class.new(Roda).class_eval{route{|_| "b2"}; app}
    app.freeze

    body("/a").must_equal 'a1'
    body("/b").must_equal 'b1'
    body("/b/a").must_equal 'b2'
    body.must_equal 'c'

    proc{app.run "a", Class.new(Roda).class_eval{route{|_| "a1"}; app}}.must_raise
  end

  it "supports multi_run_apps" do
    app(:multi_run){|r|}
    app.multi_run_apps.must_equal({})
    a = Class.new(Roda).class_eval{route{|_| "a1"}; app}
    app.run :a, a
    app.multi_run_apps.must_equal('a'=>a)
  end

  it "works when subclassing" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    app.run "a", Class.new(Roda).class_eval{route{|_| "a1"}; app}
    body("/a").must_equal 'a1'

    a = app
    @app = Class.new(a)

    a.run "b", Class.new(Roda).class_eval{route{|_| "b2"}; app}
    app.run "b", Class.new(Roda).class_eval{route{|_| "b1"}; app}

    body("/a").must_equal 'a1'
    body("/b").must_equal 'b1'

    @app = a
    body("/b").must_equal 'b2'
  end

  it "yields prefix" do
    yielded = false

    app(:multi_run) do |r|
      r.multi_run do |prefix|
        yielded = prefix
      end
    end

    app.run "a", Class.new(Roda).class_eval{route{|_| "a1"}; app}

    body("/a").must_equal "a1"
    yielded.must_equal "a"
  end

  it "allows removing dispatching to apps" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    app.run "a", Class.new(Roda).class_eval{route{|_| "a1"}; app}
    body("/a").must_equal 'a1'
    app.run "a"
    body("/a").must_equal 'c'
  end
end

describe "multi_run plugin with blocks for Roda.run" do 
  it "adds Roda.run method for setting up prefix delegations to other rack apps" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    loaded = []
    app.run("a"){loaded << :a1; Class.new(Roda).class_eval{route{|_| "a1"}; app}}

    body("/a").must_equal 'a1'
    body("/b").must_equal 'c'
    body("/b/a").must_equal 'c'
    body.must_equal 'c'
    loaded.must_equal [:a1]

    app.run("b"){loaded << :b1; Class.new(Roda).class_eval{route{|_| "b1"}; app}}

    body("/a").must_equal 'a1'
    body("/b").must_equal 'b1'
    body("/b/a").must_equal 'b1'
    body.must_equal 'c'
    loaded.must_equal [:a1, :a1, :b1, :b1]

    app.run("b/a"){loaded << :b2; Class.new(Roda).class_eval{route{|_| "b2"}; app}}

    body("/a").must_equal 'a1'
    body("/b").must_equal 'b1'
    body("/b/a").must_equal 'b2'
    body.must_equal 'c'
    loaded.must_equal [:a1, :a1, :b1, :b1, :a1, :b1, :b2]
  end

  it "works when freezing the app" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    app.run("a"){Class.new(Roda).class_eval{route{|_| "a1"}; app}}
    app.run("b"){Class.new(Roda).class_eval{route{|_| "b1"}; app}}
    app.run("b/a"){Class.new(Roda).class_eval{route{|_| "b2"}; app}}
    app.freeze

    body("/a").must_equal 'a1'
    body("/b").must_equal 'b1'
    body("/b/a").must_equal 'b2'
    body.must_equal 'c'

    proc{app.run "a", Class.new(Roda).class_eval{route{|_| "a1"}; app}}.must_raise
  end

  it "works when subclassing" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    app.run("a"){Class.new(Roda).class_eval{route{|_| "a1"}; app}}
    body("/a").must_equal 'a1'

    a = app
    @app = Class.new(a)

    a.run("b"){Class.new(Roda).class_eval{route{|_| "b2"}; app}}
    app.run("b"){Class.new(Roda).class_eval{route{|_| "b1"}; app}}

    body("/a").must_equal 'a1'
    body("/b").must_equal 'b1'

    @app = a
    body("/b").must_equal 'b2'
  end

  it "yields prefix" do
    yielded = false

    app(:multi_run) do |r|
      r.multi_run do |prefix|
        yielded = prefix
      end
    end

    app.run("a"){Class.new(Roda).class_eval{route{|_| "a1"}; app}}

    body("/a").must_equal "a1"
    yielded.must_equal "a"
  end

  it "allows removing dispatching to apps" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    app.run("a"){Class.new(Roda).class_eval{route{|_| "a1"}; app}}
    body("/a").must_equal 'a1'
    app.run "a"
    body("/a").must_equal 'c'
  end

  it "does not allow registering both app and app block in same call" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    proc{app.run("a", Class.new){}}.must_raise Roda::RodaError
  end

  it "registering app removes app block and vice versa" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    body("/a").must_equal 'c'
    app.run "a", Class.new(Roda).class_eval{route{|_| "a1"}; app}
    body("/a").must_equal 'a1'
    app.run("a"){Class.new(Roda).class_eval{route{|_| "a2"}; app}}
    body("/a").must_equal 'a2'
    app.run "a", Class.new(Roda).class_eval{route{|_| "a3"}; app}
    body("/a").must_equal 'a3'
    app.run "a"
    body("/a").must_equal 'c'
  end

  it "supports both apps and app blocks" do
    app(:multi_run) do |r|
      r.multi_run
      "c"
    end

    app.run "a", Class.new(Roda).class_eval{route{|_| "a"}; app}
    app.run("b"){Class.new(Roda).class_eval{route{|_| "b"}; app}}
    body("/a").must_equal 'a'
    body("/b").must_equal 'b'
  end
end
