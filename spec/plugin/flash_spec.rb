require_relative "../spec_helper"

describe "flash plugin" do 
  include CookieJar

  [lambda{send(*DEFAULT_SESSION_ARGS); plugin :flash},
   lambda{plugin :flash; send(*DEFAULT_SESSION_ARGS)}].each do  |config|

    it "flash.now[] sets flash for current page" do
      app(:bare) do
        instance_exec(&config)

        route do |r|
          r.on do
            flash.now['a'] = 'b'
            flash['a']
          end
        end
      end

      body.must_equal 'b'
    end

    it "flash[] sets flash for next page" do
      app(:bare) do
        instance_exec(&config)

        route do |r|
          r.get('a'){"c#{flash['a']}"}
          r.get('f'){flash; session['_flash'].inspect}

          flash['a'] = "b#{flash['a']}"
          flash['a'] || ''
        end
      end

      body.must_equal ''
      body.must_equal 'b'
      body.must_equal 'bb'

      body('/a').must_equal 'cbbb'
      body.must_equal ''
      body.must_equal 'b'
      body.must_equal 'bb'

      body('/f').must_match(/\A\{"a" ?=> ?"bbb"\}\z/)
      body('/f').must_equal 'nil'
    end

    it "works correctly if flash not accessed" do
      app(:bare) do
        instance_exec(&config)
        route{|_| 'a'}
      end
      body.must_equal 'a'
    end
  end
end

describe "FlashHash" do 
  before do
    require 'roda/plugins/flash'
    @h = Roda::RodaPlugins::Flash::FlashHash.new
  end

  it ".new should accept nil for empty hash" do
    @h = Roda::RodaPlugins::Flash::FlashHash.new(nil)
    @h.now.must_equal({})
    @h.next.must_equal({})
  end

  it ".new should accept a hash" do
    @h = Roda::RodaPlugins::Flash::FlashHash.new(1=>2)
    @h.now.must_equal(1=>2)
    @h.next.must_equal({})
  end

  it "#[]= assigns to next flash" do
    @h[1] = 2
    @h.now.must_equal({})
    @h.next.must_equal(1=>2)
  end

  it "#discard removes given key from next hash" do
    @h[1] = 2
    @h[nil] = 3
    @h.next.must_equal(1=>2, nil=>3)
    @h.discard(nil)
    @h.next.must_equal(1=>2)
    @h.discard(1)
    @h.next.must_equal({})
  end

  it "#discard removes all entries from next hash with no arguments" do
    @h[1] = 2
    @h[nil] = 3
    @h.next.must_equal(1=>2, nil=>3)
    @h.discard
    @h.next.must_equal({})
  end

  it "#keep copies entry for key from current hash to next hash" do
    @h.now[1] = 2
    @h.now[nil] = 3
    @h.next.must_equal({})
    @h.keep(nil)
    @h.next.must_equal(nil=>3)
    @h.keep(1)
    @h.next.must_equal(1=>2, nil=>3)
  end

  it "#keep copies all entries from current hash to next hash" do
    @h.now[1] = 2
    @h.now[nil] = 3
    @h.next.must_equal({})
    @h.keep
    @h.next.must_equal(1=>2, nil=>3)
  end

  it "#sweep replaces current hash with next hash" do
    @h[1] = 2
    @h[nil] = 3
    @h.next.must_equal(1=>2, nil=>3)
    @h.now.must_equal({})
    @h.sweep.must_equal(1=>2, nil=>3)
    @h.next.must_equal({})
    @h.now.must_equal(1=>2, nil=>3)
  end
end
