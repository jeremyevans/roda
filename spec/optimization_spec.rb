require_relative "spec_helper"

[true, false].each do |frozen|
  describe(frozen ? "optimized matchers for frozen applications" : "matchers") do
    if frozen
      def app(*)
        super.freeze
      end
    end

    it "r.is without arguments should only match if already matched" do
      app do |r|
        r.is do |*args|
          args.length.to_s
        end
        ''
      end

      unless_lint do
        body('').must_equal '0'
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal ''
      body('/fo').must_equal ''
      body('/foo').must_equal ''
      body('/foo/').must_equal ''
      body('/foo/1').must_equal ''
    end

    it "r.get and r.post without arguments should only match if already matched" do
      app do |r|
        r.get do |*args|
          "get-#{args.length}"
        end
        r.post do |*args|
          "post-#{args.length}"
        end
        ''
      end

      unless_lint do
        body('').must_equal 'get-0'
        body('', 'REQUEST_METHOD'=>'POST').must_equal 'post-0'
        body('', 'REQUEST_METHOD'=>'PUT').must_equal ''
      end
    end

    [:is, :get].each do |meth|
      it "r.#{meth} true should only match if already matched" do
        app do |r|
          r.send(meth, true) do |*args|
            args.length.to_s
          end
          ''
        end

        unless_lint do
          body('').must_equal '0'
          body('fo').must_equal ''
          body('foo').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal ''
        body('/foo').must_equal ''
        body('/foo/').must_equal ''
        body('/foo/1').must_equal ''
      end

      it "r.#{meth} 'string' should match only final segment containing the string" do
        app do |r|
          r.send(meth, 'foo') do |*args|
            "foo-#{args.length}"
          end
          ''
        end

        unless_lint do
          body('fo').must_equal ''
          body('foo').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal ''
        body('/foo').must_equal 'foo-0'
        body('/foo/').must_equal ''
        body('/foo/1').must_equal ''
      end

      it "r.#{meth} String should match only final segment" do
        app do |r|
          r.send(meth, String) do |*args|
            args.inspect
          end
          ''
        end

        unless_lint do
          body('fo').must_equal ''
          body('foo').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal '["fo"]'
        body('/foo').must_equal '["foo"]'
        body('/foo/').must_equal ''
        body('/foo/1').must_equal ''
      end

      it "r.#{meth} Integer should match only final segment of 1-100 decimal characters" do
        app do |r|
          r.send(meth, Integer) do |*args|
            args.inspect
          end
          ''
        end

        unless_lint do
          body('fo').must_equal ''
          body('foo').must_equal ''
          body('1').must_equal ''
          body('2').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal ''
        body('/foo').must_equal ''
        body('/foo/').must_equal ''
        body('/foo/1').must_equal ''
        body('/1').must_equal '[1]'
        body('/2').must_equal '[2]'
        body('/1/').must_equal ''
        body('/2/1').must_equal ''

        body('/'+'2'*100).must_equal '['+'2'*100+']'
        body('/'+'2'*101).must_equal ''
      end

      it "r.#{meth} with other supported class argument should match if one if the elements matches" do
        app(:bare) do
          plugin :class_matchers
          class_matcher(Float, /(\d+\.\d+)/) do |str|
            [str.to_f]
          end
          route do |r|
            r.send meth, Float do |arg|
              "#{arg.class}-#{arg}-#{r.remaining_path}"
            end
            ''
          end
        end

        unless_lint do
          body('').must_equal ''
          body('fo').must_equal ''
          body('123.3').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal ''
        body('/123.3').must_equal 'Float-123.3-'
        body('/123.3/').must_equal ''
        body('/123.3/1').must_equal ''
      end

      it "r.#{meth} with unsupported class should raise" do
        app do |r|
          r.send(meth, Array) do |*args|
            args.inspect
          end
          ''
        end

        proc{body}.must_raise Roda::RodaError
      end

      it "r.#{meth} /regexp/ should match only final segment" do
        app do |r|
          r.send(meth, /(foo?)/) do |*args|
            args.inspect
          end
          ''
        end

        unless_lint do
          body('fo').must_equal ''
          body('foo').must_equal ''
        end
        body.must_equal ''
        body('/f').must_equal ''
        body('/fo').must_equal '["fo"]'
        body('/foo').must_equal '["foo"]'
        body('/food').must_equal ''
        body('/foo/').must_equal ''
        body('/foo/1').must_equal ''
      end

      it "r.#{meth} String, Integer should match only string segment followed by final integer segment" do
        app do |r|
          r.send(meth, String, Integer) do |*args|
            args.inspect
          end
          ''
        end

        unless_lint do
          body('fo').must_equal ''
          body('foo').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal ''
        body('/foo').must_equal ''
        body('/foo/').must_equal ''
        body('/foo/1').must_equal '["foo", 1]'
        body('/foo/1/').must_equal ''

        body('/foo/'+'2'*100).must_equal '["foo", '+'2'*100+']'
        body('/foo/'+'2'*101).must_equal ''
      end

      it "r.#{meth} with false argument should never match" do
        app do |r|
          r.send(meth, false) do |*args|
            args.length.to_s
          end
          ''
        end

        unless_lint do
          body('').must_equal ''
          body('fo').must_equal ''
          body('foo').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal ''
        body('/foo').must_equal ''
        body('/foo/').must_equal ''
        body('/foo/1').must_equal ''
      end

      it "r.#{meth} with nil argument should never match" do
        app do |r|
          r.send(meth, nil) do |*args|
            args.length.to_s
          end
          ''
        end

        unless_lint do
          body('').must_equal ''
          body('fo').must_equal ''
          body('foo').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal ''
        body('/foo').must_equal ''
        body('/foo/').must_equal ''
        body('/foo/1').must_equal ''
      end

      it "r.#{meth} with array argument should match if one if the elements matches" do
        app do |r|
          r.send(meth, ['fo', 'foo']) do |arg|
            "#{arg}-#{r.remaining_path}"
          end
          ''
        end

        unless_lint do
          body('').must_equal ''
          body('fo').must_equal ''
          body('foo').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal 'fo-'
        body('/foo').must_equal 'foo-'
        body('/foo/').must_equal ''
        body('/foo/1').must_equal ''
      end

      it "r.#{meth} with hash argument should match if one if hash matches" do
        app do |r|
          r.send(meth, :all=>['fo', 'foo']) do |*args|
            "#{args.length}-#{r.remaining_path}"
          end
          ''
        end

        unless_lint do
          body('').must_equal ''
          body('fo').must_equal ''
          body('foo').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal ''
        body('/foo').must_equal ''
        body('/fo/foo').must_equal '0-'
        body('/fo/foo/').must_equal ''
        body('/fo/foo/1').must_equal ''
      end

      it "r.#{meth} with symbol argument should match next segment if non-empty" do
        app do |r|
          r.send(meth, :foo) do |*args|
            "#{args.inspect}-#{r.remaining_path}"
          end
          ''
        end

        unless_lint do
          body('fo').must_equal ''
          body('foo').must_equal ''
        end
        body.must_equal ''
        body('/fo').must_equal '["fo"]-'
        body('/foo').must_equal '["foo"]-'
        body('/foo/').must_equal ''
        body('/foo/1').must_equal ''
      end

      it "r.#{meth} with proc argument should match unless it returns nil/false" do
        x = nil
        app do |r|
          r.send(meth, proc{request.remaining_path.clear if request.remaining_path == '/'; x}) do |*args|
            args.length.to_s
          end
          ''
        end

        body.must_equal ''
        x = false
        body.must_equal ''
        x = true
        body.must_equal '0'
        body("/a").must_equal ''
      end

      it "r.#{meth} with custom argument should match if one if the elements matches" do
        x = Object.new
        app(:bare) do
          plugin :custom_matchers
          custom_matcher(Object) do |obj|
            @captures << obj.object_id.to_s
            @remaining_path = '' if @remaining_path == '/'
          end
          route do |r|
            r.send(meth, x) do |arg|
              "#{arg}-#{r.remaining_path}"
            end
            ''
          end
        end

        body.must_equal "#{x.object_id}-"
        body('/a').must_equal ""
      end
    end

    it "r.on without arguments should always match" do
      app do |r|
        r.on do |*args|
          args.length.to_s
        end
        ''
      end

      unless_lint do
        body('').must_equal '0'
        body('fo').must_equal '0'
        body('foo').must_equal '0'
      end
      body.must_equal '0'
      body('/fo').must_equal '0'
      body('/foo').must_equal '0'
      body('/foo/').must_equal '0'
      body('/foo/1').must_equal '0'
    end

    it "r.on true should always match" do
      app do |r|
        r.on true do |*args|
          args.length.to_s
        end
        ''
      end

      unless_lint do
        body('').must_equal '0'
        body('fo').must_equal '0'
        body('foo').must_equal '0'
      end
      body.must_equal '0'
      body('/fo').must_equal '0'
      body('/foo').must_equal '0'
      body('/foo/').must_equal '0'
      body('/foo/1').must_equal '0'
    end

    it "r.on 'string' should match string against next segment" do
      app do |r|
        r.on('foo') do |*args|
          "foo-#{args.length}-#{r.remaining_path}"
        end
        ''
      end

      unless_lint do
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal ''
      body('/fo').must_equal ''
      body('/foo').must_equal 'foo-0-'
      body('/foo/').must_equal 'foo-0-/'
      body('/foo/1').must_equal 'foo-0-/1'
    end

    it "r.on String should match next segment if non-empty" do
      app do |r|
        r.on(String) do |*args|
          "#{args.inspect}-#{r.remaining_path}"
        end
        ''
      end

      unless_lint do
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal ''
      body('//').must_equal ''
      body('/fo').must_equal '["fo"]-'
      body('/foo').must_equal '["foo"]-'
      body('/foo/').must_equal '["foo"]-/'
      body('/foo/1').must_equal '["foo"]-/1'
    end

    it "r.on Integer should match next segment if integer" do
      app do |r|
        r.on(Integer) do |*args|
          "#{args.inspect}-#{r.remaining_path}"
        end
        ''
      end

      unless_lint do
        body('fo').must_equal ''
        body('foo').must_equal ''
        body('1').must_equal ''
        body('2').must_equal ''
      end
      body.must_equal ''
      body('/fo').must_equal ''
      body('/foo').must_equal ''
      body('/foo/').must_equal ''
      body('/foo/1').must_equal ''
      body('/1').must_equal '[1]-'
      body('/2').must_equal '[2]-'
      body('/1/').must_equal '[1]-/'
      body('/2/1').must_equal '[2]-/1'

      body('/'+'2'*100).must_equal '['+'2'*100+']-'
      body('/'+'2'*101).must_equal ''
    end

    it "r.on with unsupported class should raise" do
      app do |r|
        r.on(Array) do |*args|
          args.inspect
        end
        ''
      end

      proc{body}.must_raise Roda::RodaError
    end

    it "r.on /regexp/ should match regexp against next segment" do
      app do |r|
        r.on(/(foo?)/) do |*args|
          "#{args.inspect}-#{r.remaining_path}"
        end
        ''
      end

      unless_lint do
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal ''
      body('/f').must_equal ''
      body('/fo').must_equal '["fo"]-'
      body('/foo').must_equal '["foo"]-'
      body('/food').must_equal ''
      body('/foo/').must_equal '["foo"]-/'
      body('/foo/1').must_equal '["foo"]-/1'
    end

    it "r.on String, Integer should match string segment followed by integer segment" do
      app do |r|
        r.on(String, Integer) do |*args|
          "#{args.inspect}-#{r.remaining_path}"
        end
        ''
      end

      unless_lint do
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal ''
      body('/fo').must_equal ''
      body('/foo').must_equal ''
      body('/foo/').must_equal ''
      body('/foo/1').must_equal '["foo", 1]-'
      body('/foo/1/').must_equal '["foo", 1]-/'
      body('/fo/2/a').must_equal '["fo", 2]-/a'
    end

    it "r.is with slash_path_empty should match remaining path with only slash" do
      app(:slash_path_empty) do |r|
        r.is do |*args|
          args.length.to_s
        end
        ''
      end

      unless_lint do
        body('').must_equal '0'
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal '0'
      body('/fo').must_equal ''
      body('/foo').must_equal ''
      body('/foo/').must_equal ''
      body('/foo/1').must_equal ''
    end

    it "r.on with true argument should always match" do
      app do |r|
        r.on true do |*args|
          args.length.to_s
        end
        ''
      end

      unless_lint do
        body('').must_equal '0'
        body('fo').must_equal '0'
        body('foo').must_equal '0'
      end
      body.must_equal '0'
      body('/fo').must_equal '0'
      body('/foo').must_equal '0'
      body('/foo/').must_equal '0'
      body('/foo/1').must_equal '0'
    end

    it "r.on with false argument should never match" do
      app do |r|
        r.on false do |*args|
          args.length.to_s
        end
        ''
      end

      unless_lint do
        body('').must_equal ''
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal ''
      body('/fo').must_equal ''
      body('/foo').must_equal ''
      body('/foo/').must_equal ''
      body('/foo/1').must_equal ''
    end

    it "r.on with nil argument should never match" do
      app do |r|
        r.on nil do |*args|
          args.length.to_s
        end
        ''
      end

      unless_lint do
        body('').must_equal ''
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal ''
      body('/fo').must_equal ''
      body('/foo').must_equal ''
      body('/foo/').must_equal ''
      body('/foo/1').must_equal ''
    end

    it "r.on with array argument should match if one if the elements matches" do
      app do |r|
        r.on ['fo', 'foo'] do |arg|
          "#{arg}-#{r.remaining_path}"
        end
        ''
      end

      unless_lint do
        body('').must_equal ''
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal ''
      body('/fo').must_equal 'fo-'
      body('/foo').must_equal 'foo-'
      body('/foo/').must_equal 'foo-/'
      body('/foo/1').must_equal 'foo-/1'
    end

    it "r.on with hash argument should match if one if hash matches" do
      app do |r|
        r.on :all=>['fo', 'foo'] do |*args|
          "#{args.length}-#{r.remaining_path}"
        end
        ''
      end

      unless_lint do
        body('').must_equal ''
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal ''
      body('/fo').must_equal ''
      body('/foo').must_equal ''
      body('/fo/foo').must_equal '0-'
      body('/fo/foo/').must_equal '0-/'
      body('/fo/foo/1').must_equal '0-/1'
    end

    it "r.on with symbol argument should match next segment if non-empty" do
      app do |r|
        r.on(:foo) do |*args|
          "#{args.inspect}-#{r.remaining_path}"
        end
        ''
      end

      unless_lint do
        body('fo').must_equal ''
        body('foo').must_equal ''
      end
      body.must_equal ''
      body('/fo').must_equal '["fo"]-'
      body('/foo').must_equal '["foo"]-'
      body('/foo/').must_equal '["foo"]-/'
      body('/foo/1').must_equal '["foo"]-/1'
    end

    it "r.on with proc argument should match unless it returns nil/false" do
      x = nil
      app do |r|
        r.on(proc{x}) do |*args|
          args.length.to_s
        end
        ''
      end

      body.must_equal ''
      x = false
      body.must_equal ''
      x = true
      body.must_equal '0'
    end

    it "r.on with class argument should match if one if the elements matches" do
      app(:bare) do
        plugin :class_matchers
        class_matcher(Float, /(\d+\.\d+)/) do |str|
          [str.to_f]
        end
        route do |r|
          r.on Float do |arg|
            "#{arg.class}-#{arg}-#{r.remaining_path}"
          end
          ''
        end
      end

      unless_lint do
        body('').must_equal ''
        body('fo').must_equal ''
        body('123.3').must_equal ''
      end
      body.must_equal ''
      body('/fo').must_equal ''
      body('/123.3').must_equal 'Float-123.3-'
      body('/123.3/').must_equal 'Float-123.3-/'
      body('/123.3/1').must_equal 'Float-123.3-/1'
    end

    it "r.on with custom argument should match if one if the elements matches" do
      x = Object.new
      app(:bare) do
        plugin :custom_matchers
        custom_matcher(Object) do |obj|
          @captures << obj.object_id.to_s
        end
        route do |r|
          r.on x do |arg|
            "#{arg}-#{r.remaining_path}"
          end
          ''
        end
      end

      body.must_equal "#{x.object_id}-/"
    end
  end
end
