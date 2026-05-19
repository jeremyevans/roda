require_relative "../spec_helper"
require 'date'

describe "class_matchers plugin" do 
  [nil, true].each do |segment|
    munge_segment = segment && RUBY_VERSION >= "2.4"

    it "allows class specific regexps with type conversion for class matchers#{" when using segment: true for regexps" if segment}" do
      app(:bare) do
        plugin :class_matchers
        class_matcher(Date, /(\d\d\d\d)-(\d\d)-(\d\d)/){|y,m,d| Date.new(y.to_i, m.to_i, d.to_i) if Date.valid_date?(y.to_i, m.to_i, d.to_i)}
        class_matcher(Array, /(\w+)\/(\w+)/){|a, b| [[a, 1], [b, 2]]}
        class_matcher(Hash, /(\d+)\/(\d+)/){|a, b| [{a.to_i=>b.to_i}]}

        klass = Class.new
        def klass.to_s; "klass" end
        class_matcher(klass, Integer){|i| i*2 unless i == 10}

        plugin :symbol_matchers
        symbol_matcher(:i, /i(\d+)/, segment: segment) do |i|
          i = i[1..-1] if munge_segment
          i.to_i
        end
        klass2 = Class.new
        def klass2.to_s; "klass2" end
        class_matcher(klass2, :i){|i| i*3}

        symbol_matcher(:j, /j(\d+)/, segment: segment)
        klass3 = Class.new
        def klass3.to_s; "klass3" end
        class_matcher(klass3, :j) do |j|
          j = j[1..-1] if munge_segment
          j*3
        end

        klass4 = Class.new
        def klass4.to_s; "klass4" end
        class_matcher(klass4, String){|i| i*2}

        klass5 = Class.new
        def klass5.to_s; "klass5" end
        class_matcher(klass5, klass){|i| i*3}

        klass6 = Class.new
        def klass6.to_s; "klass6" end
        class_matcher(klass6, klass)

        klass7 = Class.new
        def klass7.to_s; "klass7" end
        class_matcher(klass7, String)

        klass8 = Class.new
        def klass8.to_s; "klass8" end
        class_matcher(klass8, :d){|i| i*2}

        klass9 = Class.new
        def klass9.to_s; "klass9" end
        class_matcher(klass9, :d)

        route do |r|
          r.on Array do |(a,b), (c,d)|
            r.get 'X', klass5 do |i|
              [a, b, c, d, i].join('-')
            end
            r.get 'Y', [klass6, klass7] do |i|
              [a, b, c, d, i].join('-')
            end
            r.get 'Z1', klass8 do |i|
              [a, b, c, d, i].join('-')
            end
            r.get 'Z2', klass9 do |i|
              [a, b, c, d, i].join('-')
            end
            r.get Date do |date|
              [date.year, date.month, date.day, a, b, c, d].join('-')
            end
            r.get Hash do |h|
              [h.to_a.inspect, a, b, c, d].join('-')
            end
            r.get Array do |(a1,b1), (c1,d1)|
              [a1, b1, c1, d1, a, b, c, d].join('-')
            end
            r.get klass do |i|
              [a, b, c, d, i].join('-') + '-1'
            end
            r.get klass2 do |i|
              [a, b, c, d, i].join('-') + '-2'
            end
            r.get klass3 do |i|
              [a, b, c, d, i].join('-') + '-3'
            end
            r.get klass4 do |i|
              [a, b, c, d, i].join('-') + '-4'
            end
            r.is do
              [a, b, c, d].join('-')
            end
            "array"
          end
          ""
        end
      end

      body("/c").must_equal ''
      body("/c/d").must_equal 'c-1-d-2'
      body("/c/d/e/f/g").must_equal 'array'
      body("/c/d/2009-10-a").must_equal 'c-1-d-2-2009-10-a2009-10-a-4'
      body("/c/d/2009-10-01").must_equal '2009-10-1-c-1-d-2'
      body("/c/d/2009-13-01").must_equal "c-1-d-2-2009-13-012009-13-01-4"
      body("/c/d/1/2").must_equal '[[1, 2]]-c-1-d-2'
      body("/c/d/e/f").must_equal 'e-1-f-2-c-1-d-2'
      body("/c/d/3").must_equal 'c-1-d-2-6-1'
      body("/c/d/10").must_equal 'c-1-d-2-1010-4'
      body("/c/d/i3").must_equal 'c-1-d-2-9-2'
      body("/c/d/j3").must_equal 'c-1-d-2-333-3'
      body("/c/d/i").must_equal 'c-1-d-2-ii-4'
      body("/c/d/X/3").must_equal 'c-1-d-2-18'
      body("/c/d/X/10").must_equal 'X-1-10-2-c-1-d-2'
      body("/c/d/Y/3").must_equal 'c-1-d-2-6'
      body("/c/d/Y/a").must_equal 'c-1-d-2-a'
      body("/c/d/Z1/3").must_equal 'c-1-d-2-33'
      body("/c/d/Z2/3").must_equal 'c-1-d-2-3'
    end
  end

  it "raises errors for unsupported calls to class matcher" do
    app(:class_matchers){}
    c = Class.new
    proc{app.class_matcher(:foo, /a/)}.must_raise Roda::RodaError
    proc{app.class_matcher(c, Hash)}.must_raise Roda::RodaError
    proc{app.class_matcher(c, :foo)}.must_raise Roda::RodaError
    app.plugin :symbol_matchers
    proc{app.class_matcher(c, :foo)}.must_raise Roda::RodaError
    proc{app.class_matcher(c, Object.new)}.must_raise Roda::RodaError
  end

  it "respects Integer_matcher_max plugin when using class_matcher with Integer matcher" do
    c = Class.new
    app(:class_matchers){|r| r.is(c){|x| (x*3).to_s}}
    app.class_matcher(c, Integer)
    body("/4").must_equal "12"
    body("/1000000000000000000000").must_equal "3000000000000000000000"
    app.plugin :Integer_matcher_max
    body("/1000000000000000000000").must_equal ""
    app.plugin :Integer_matcher_max, 1000000000000000000000
    body("/1000000000000000000000").must_equal "3000000000000000000000"
    body("/1000000000000000000001").must_equal ""
  end

  it "respects Integer_matcher_max plugin when loaded first" do
    c = Class.new
    app(:bare) do
      plugin :Integer_matcher_max
      plugin :class_matchers
      route{|r| r.is(c){|x| (x*3).to_s}}
    end
    app.class_matcher(c, Integer)
    body("/4").must_equal "12"
    body("/1000000000000000000000").must_equal ""
    app.plugin :Integer_matcher_max, 1000000000000000000000
    body("/1000000000000000000000").must_equal "3000000000000000000000"
    body("/1000000000000000000001").must_equal ""
  end

  it "handles conversion block returning falsey for matcher based on String " do
    app(:class_matchers) do |r|
      r.is(Array){|s| s}
      r.remaining_path
    end
    app.class_matcher(Array, String){|s| s*2 unless s == 'a'}
    body('/a').must_equal '/a'
    body('/b').must_equal 'bb'
  end

  it "yields multiple arguments in matcher based on String " do
    app(:class_matchers) do |r|
      r.is(Array){|s, s2| "#{s}-#{s2}"}
    end
    app.class_matcher(Array, String){|s| [s, s*2]}
    body('/a').must_equal 'a-aa'
  end

  it "yields hash instances as single arguments" do
    app(:class_matchers) do |r|
      r.is('a', Array){|h| h.to_a.join(',')}
      r.is('h', Hash){|h| h.to_a.join('-')}
    end
    app.class_matcher(Hash, /(\w)(\w)/){|k,v| {k=>v}}
    app.class_matcher(Array, Hash){|h| h['c'] = 'd'; h }
    body('/h/ab').must_equal 'a-b'
    body('/a/ab').must_equal 'a,b,c,d'
  end

  it "freezes :class_matchers option when freezing app" do
    app(:class_matchers){|r| }
    app.freeze
    app.opts[:class_matchers].frozen?.must_equal true
  end
end
