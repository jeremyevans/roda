require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

describe "json plugin" do
  describe "response conversion" do
    before do
      c = Class.new do
        def to_json
          '[1]'
        end
      end

      app(:bare) do
        plugin :json, :classes=>[Array, Hash, c]

        route do |r|
          r.is 'array' do
            [1, 2, 3]
          end

          r.is "hash" do
            {'a'=>'b'}
          end

          r.is 'c' do
            c.new
          end
        end
      end
    end

    it "should use a json content type for a json response" do
      header('Content-Type', "/array").should == 'application/json'
      header('Content-Type', "/hash").should == 'application/json'
      header('Content-Type', "/c").should == 'application/json'
      header('Content-Type').should == 'text/html'
    end

    it "should convert objects to json" do
      body('/array').gsub(/\s/, '').should == '[1,2,3]'
      body('/hash').gsub(/\s/, '').should == '{"a":"b"}'
      body('/c').should == '[1]'
      body.should == ''
    end

    it "should work when subclassing" do
      @app = Class.new(app)
      app.route{[1]}
      body.should == '[1]'
    end
  end

  describe "request body" do

    let(:hash){ {foo: "bar", baz: 2, bat: true} }
    let(:json){ hash.to_json }

    describe "parsing" do
      before do
        app(:bare) do
          plugin :json, :request_body => true

          route do |r|
            r.on do
              params
            end
          end
        end
      end


      it "should parse json request bodies" do
        body('CONTENT_TYPE'=>'application/json', 'rack.input'=>StringIO.new(json)).should == json
      end

      it "should merge json values over query string values" do
        body('CONTENT_TYPE'=>'application/json',
             'rack.input'=>StringIO.new(json),
             'QUERY_STRING'=>'foo=notthis&baz=[not,this,either]&bat=false').should == json
      end

      it "does not die on malformed json" do
        status('CONTENT_TYPE'=>'application/json', 'rack.input'=>StringIO.new('!@#%(%*!')).should == 400
      end
    end

    describe "works with indifferent_params" do
      describe "specified before" do
        before do
          app(:bare) do
            plugin :indifferent_params
            plugin :json, :request_body => true

            route do |r|
              r.on 'foo' do
                {foo: params[:foo]}
              end
              r.on 'bar/baz/bat' do
                {bat: params[:bar][params[:baz]][:bat]}
              end
            end
          end
        end

        it "should indifference parsed bodies" do
          body('/foo', 'CONTENT_TYPE'=>'application/json', 'rack.input'=>StringIO.new(json)).should == '{"foo":"bar"}'
        end

        it "should recursively indifference parsed bodies" do
          body('/bar/baz/bat',
               'CONTENT_TYPE'=>'application/json',
               'rack.input'=>StringIO.new({bar:[0,"this",{bat:"self"}],baz:2}.to_json)
              ).should == '{"bat":"self"}'
        end
      end

      describe "specified after" do
        before do
          app(:bare) do
            plugin :json, :request_body => true
            plugin :indifferent_params

            route do |r|
              r.on 'foo' do
                {foo: params[:foo]}
              end
              r.on 'bar/baz/bat' do
                {bat: params[:bar][params[:baz]][:bat]}
              end
            end
          end
        end

        it "should indifference parsed bodies" do
          body('/foo', 'CONTENT_TYPE'=>'application/json', 'rack.input'=>StringIO.new(json)).should == '{"foo":"bar"}'
        end

        it "should recursively indifference parsed bodies" do
          body('/bar/baz/bat',
               'CONTENT_TYPE'=>'application/json',
               'rack.input'=>StringIO.new({bar:[0,"this",{bat:"self"}],baz:2}.to_json)
              ).should == '{"bat":"self"}'
        end
      end
    end
  end
end
