require_relative "../spec_helper"

describe "symbol_matchers plugin" do 
  [nil, true].each do |segment|
    it "allows symbol specific regexps for symbol matchers#{" when using segment: true for regexps" if segment}" do
      app(:bare) do
        plugin :symbol_matchers
        symbol_matcher(:d2, :d)

        symbol_matcher(:f, /(f+)/, segment: segment)
        symbol_matcher(:f2, :f) do |fs|
          fs*2
        end
        symbol_matcher(:f3, :f)

        symbol_matcher(:c, /(c+)/, segment: segment) do |cs|
          [cs, cs.length] unless cs.length == 5
        end
        symbol_matcher(:c2, :c) do |cs, len|
          len
        end
        symbol_matcher(:c3, :c)

        plugin :class_matchers
        symbol_matcher(:int, Integer) do |i|
          i*2
        end
        symbol_matcher(:i, Integer)
        symbol_matcher(:str, String) do |s|
          s*2
        end
        symbol_matcher(:s, String)

        route do |r|
          r.on "X" do
            r.is "d2", :d2 do |x|
              "d2-#{x}"
            end
            r.is "f", :f do |x|
              "f-#{x}"
            end
            r.is "f2", :f2 do |x|
              "f2-#{x}"
            end
            r.is "f3", :f3 do |x|
              "f3-#{x}"
            end
            r.is "c", :c do |x, len|
              "c-#{x}-#{len}"
            end
            r.is "c2", :c2 do |x|
              "c2-#{x}"
            end
            r.is "c3", :c3 do |x, len|
              "c3-#{x}-#{len}"
            end
            r.is "int", :int do |x|
              "int-#{x}"
            end
            r.is "i", :i do |x|
              "i-#{x}"
            end
            r.is "str", :str do |x|
              "str-#{x}"
            end
            r.is "s", :s do |x|
              "s-#{x}"
            end
          end

          r.is :d do |d|
            "d#{d}"
          end

          r.is "thing2", :thing do |d|
            "thing2#{d}"
          end

          r.is :f do |f|
            "f#{f}"
          end

          r.is :c do |cs, nc|
            "#{cs}#{nc}"
          end

          r.is 'x', :c2 do |len|
            len.inspect
          end

          r.is 'y', :int do |i|
            i.inspect
          end

          r.is 'q', :rest do |rest|
            "rest#{rest}"
          end

          r.is :w do |w|
            "w#{w}"
          end

          r.is :d, :w, :f, :c do |d, w, f, cs, nc|
            "dwfc#{d}#{w}#{f}#{cs}#{nc}"
          end
        end
      end

      status.must_equal 404
      body("/1").must_equal 'd1'
      body("/11232135").must_equal 'd11232135'
      body("/a").must_equal 'wa'
      body("/1az0").must_equal 'w1az0'
      body("/f").must_equal 'ff'
      body("/ffffffffffffffff").must_equal 'fffffffffffffffff'
      body("/c").must_equal 'c1'
      body("/cccc").must_equal 'cccc4'
      body("/ccccc").must_equal 'wccccc'
      body("/x/c").must_equal '1'
      body("/x/cccc").must_equal '4'
      body("/y/3").must_equal '6'
      status("/-").must_equal 404
      body("/1/1a/f/cc").must_equal 'dwfc11afcc2'
      body("/12/1azy/fffff/ccc").must_equal 'dwfc121azyfffffccc3'
      status("/1/f/a").must_equal 404
      body("/q/a/b/c/d//f/g").must_equal 'resta/b/c/d//f/g'
      body('/q/').must_equal 'rest'
      body('/thing2/q').must_equal 'thing2q'

      body('/X/d2/1').must_equal 'd2-1'
      body('/X/f/fff').must_equal 'f-fff'
      body('/X/f2/ff').must_equal 'f2-ffff'
      body('/X/f3/fff').must_equal 'f3-fff'
      body('/X/c/ccc').must_equal 'c-ccc-3'
      body('/X/c/ccccc').must_equal ''
      body('/X/c2/ccc').must_equal 'c2-3'
      body('/X/c2/ccccc').must_equal ''
      body('/X/c3/ccc').must_equal 'c3-ccc-3'
      body('/X/c3/ccccc').must_equal ''
      body('/X/int/3').must_equal 'int-6'
      body('/X/i/3').must_equal 'i-3'
      body('/X/str/f').must_equal 'str-ff'
      body('/X/s/f').must_equal 's-f'
    end
  end

  it "raises errors for unsupported calls to class matcher" do
    app(:symbol_matchers){|r| }
    proc{app.symbol_matcher(Hash, /a/)}.must_raise Roda::RodaError
    proc{app.symbol_matcher(:sym, :foo)}.must_raise Roda::RodaError
    proc{app.symbol_matcher(:sym, Integer)}.must_raise Roda::RodaError
    app.plugin :class_matchers
    proc{app.symbol_matcher(:sym, Hash)}.must_raise Roda::RodaError
    proc{app.symbol_matcher(:sym, Object.new)}.must_raise Roda::RodaError
  end

  it "freezes :symbol_matchers option when freezing app" do
    app(:symbol_matchers){|r| }
    app.freeze
    app.opts[:symbol_matchers].frozen?.must_equal true
  end
end
