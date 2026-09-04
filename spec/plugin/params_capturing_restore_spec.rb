require_relative "../spec_helper"

describe "params_capturing_restore plugin" do 
  it "should add captures to r.params for symbol matchers" do
    app(:params_capturing_restore) do |r|
      r.on('foo', :y, :z, :w) do |y, z, w|
        (r.params.values_at('y', 'z', 'w') + [y, z, w, r.params['captures'].length]).join('-')
      end

      r.on(/(quux)/, /(foo)(bar)/) do |q, foo, bar|
        "y-#{r.params['captures'].join}-#{q}-#{foo}-#{bar}"
      end

      r.on(/(quux)/, :y) do |q, y|
        r.on(:x) do |x|
          "y-#{r.params['y']}-#{r.params['x']}-#{q}-#{y}-#{x}-#{r.params['captures'].length}"
        end

        "y-#{r.params['y']}-#{q}-#{y}-#{r.params['captures'].length}"
      end

      r.on('z') do
        r.send(:match, :y) ? 'yes' : 'no'
      end

      r.on(:x) do |x|
        "x-#{x}-#{r.params['x']}-#{r.params['captures'].length}"
      end
    end

    body('/blarg', 'rack.input'=>rack_input).must_equal 'x-blarg-blarg-1'
    body('/foo/1/2/3', 'rack.input'=>rack_input).must_equal '1-2-3-1-2-3-3'
    body('/foo/1/2/3', 'rack.input'=>rack_input, 'QUERY_STRING'=>'captures[]=1').must_equal '1-2-3-1-2-3-3'
    body('/quux/foobar', 'rack.input'=>rack_input).must_equal 'y-quuxfoobar-quux-foo-bar'
    body('/quux/asdf', 'rack.input'=>rack_input).must_equal 'y--quux-asdf-2'
    body('/quux/asdf/890', 'rack.input'=>rack_input).must_equal 'y--890-quux-asdf-890-3'
    body('/z', 'rack.input'=>rack_input).must_equal 'no'
    body('/z/x', 'rack.input'=>rack_input).must_equal 'yes'
  end

  [:pass, :break].each do |type|
    it "should work with #{type} plugin" do
      app(:bare) do
        plugin type
        plugin :params_capturing_restore
        route do |r|
          r.on :c do |c|
            r.on :d do |d|
              r.params.to_a.sort.inspect
            end

            type == :pass ? r.pass : break
          end

          r.params.to_a.sort.inspect
        end
      end

      body('rack.input'=>rack_input).must_equal '[["captures", []]]'
      body("/a", 'rack.input'=>rack_input).must_equal '[["captures", []]]'
      body("/a/b", 'rack.input'=>rack_input).must_equal '[["c", "a"], ["captures", ["a", "b"]], ["d", "b"]]'
      body("/a", 'rack.input'=>rack_input, "QUERY_STRING"=>"c=x").must_equal '[["c", "x"], ["captures", []]]'
    end
  end
end
