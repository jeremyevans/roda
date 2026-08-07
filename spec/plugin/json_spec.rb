require_relative "../spec_helper"

describe "json plugin" do
  c = Class.new do
    def to_json
      '[1]'
    end
  end

  before do
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

        r.is 'd' do
          response[RodaResponseHeaders::CONTENT_TYPE] = 'foo'
          c.new
        end
      end
    end
  end

  it "should use a json content type for a json response" do
    header(RodaResponseHeaders::CONTENT_TYPE, "/array").must_equal 'application/json'
    header(RodaResponseHeaders::CONTENT_TYPE, "/hash").must_equal 'application/json'
    header(RodaResponseHeaders::CONTENT_TYPE, "/c").must_equal 'application/json'
    header(RodaResponseHeaders::CONTENT_TYPE).must_equal 'text/html'
  end

  it "should not override existing content type for a json response" do
    header(RodaResponseHeaders::CONTENT_TYPE, "/d").must_equal 'foo'
  end

  it "should convert objects to json" do
    body('/array').gsub(/\s/, '').must_equal '[1,2,3]'
    body('/hash').gsub(/\s/, '').must_equal '{"a":"b"}'
    body('/c').must_equal '[1]'
    body.must_equal ''
  end

  it "should work when subclassing" do
    @app = Class.new(app)
    app.route{|_| [1]}
    body.must_equal '[1]'
  end

  it "should return classes that will be converted to JSON" do
    @app.json_result_classes.must_equal [Array, Hash, c]
  end

  it "should accept custom serializers" do
    app.plugin :json, :serializer => proc{|o| o.to_a.inspect}
    body("/hash").must_equal '[["a", "b"]]'
  end

  it "should give serializer the request if :include_request is set" do
    app.plugin :json,
      :include_request => true,
      :serializer => lambda{|o,r| "#{o['a']}:#{r.path_info}"}

    body("/hash").must_equal 'b:/hash'
  end

  it "should allow resetting :include_request to false" do
    app.plugin :json, :include_request => true
    app.plugin :json, :include_request => false

    body("/hash").must_equal '{"a":"b"}'
  end

  it "should allow custom content type for a response" do
    app.plugin :json, :content_type => "application/xml"
    header(RodaResponseHeaders::CONTENT_TYPE, "/array").must_equal 'application/xml'
  end
end
