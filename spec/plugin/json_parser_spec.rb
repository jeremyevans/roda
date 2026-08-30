require_relative "../spec_helper"

describe "json_parser plugin" do 
  deprecated "parses incoming json if content type specifies json" do
    app(:json_parser){|r| r.params['a']['b'].to_s}
    body('rack.input'=>rack_input('{"a":{"b":1}}'), 'CONTENT_TYPE'=>'text/json', 'REQUEST_METHOD'=>'POST').must_equal '1'
  end
end

describe "json_parser plugin" do 
  def json_parser_app(&block)
    app(:bare) do
      plugin :json_parser, :content_type_regexp=>/\Aapplication\/json\b/i
      route(&block)
    end
  end

  before do
    json_parser_app{|r| r.params['a']['b'].to_s}
  end

  it "parses incoming json if content type specifies json" do
    body('rack.input'=>rack_input('{"a":{"b":1}}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '1'
  end

  it "Handles Rack::Request#POST being called in advance" do
    env = req_env('rack.input'=>rack_input('{"a":{"b":1}}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST')
    r = Rack::Request.new(env)
    r.POST
    body(env).must_equal '1'
  end

  it "doesn't affect parsing of non-json content type" do
    body('rack.input'=>rack_input('a[b]=1'), 'REQUEST_METHOD'=>'POST').must_equal '1'
  end

  it "parses incoming json if content type specifies json and body is already read" do
    @app.route do |r|
      r.body.read
      r.params['a']['b'].to_s
    end
    body('rack.input'=>rack_input('{"a":{"b":1}}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '1'
  end unless Rack.release >= '2.3'

  it "returns 400 for invalid json" do
    req('rack.input'=>rack_input('{"a":{"b":1}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal [400, {}, []]
  end

  it "returns 400 for invalid json when using params_capturing plugin" do
    @app.plugin :params_capturing
    req('rack.input'=>rack_input('{"a":{"b":1}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal [400, {}, []]
  end

  it "raises by default if r.params is called and a non-hash is submitted" do
    proc do
      req('rack.input'=>rack_input('[1]'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST')
    end.must_raise
  end
end

describe "json_parser plugin" do 
  def json_parser_app(&block)
    app(:bare) do
      plugin :json_parser, :content_type_regexp=>/\Aapplication\/json\b/i
      route(&block)
    end
  end

  it "handles empty request bodies" do
    json_parser_app do |r|
      r.params.length.to_s
    end
    body('rack.input'=>rack_input(''), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '0'
  end

  it "handles arrays and other non-hash values using r.POST" do
    json_parser_app do |r|
      r.POST.inspect
    end
    body('rack.input'=>rack_input('[ 1 ]'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '[1]'
  end

  it "supports :wrap=>:always option" do
    app(:bare) do
      plugin(:json_parser, :wrap=>:always, :content_type_regexp=>/\Aapplication\/json\b/i)
      route do |r|
        r.post 'a' do r.params['_json']['a']['b'].to_s end
        r.params['_json'][1].to_s
      end
    end
    body('/a', 'rack.input'=>rack_input('{"a":{"b":1}}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '1'
    body('rack.input'=>rack_input('[true, 2]'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '2'
  end

  it "supports :wrap=>:unless_hash option" do
    app(:bare) do
      plugin(:json_parser, :wrap=>:unless_hash, :content_type_regexp=>/\Aapplication\/json\b/i)
      route do |r|
        r.post 'a' do r.params['a']['b'].to_s end
        r.params['_json'][1].to_s
      end
    end
    body('/a', 'rack.input'=>rack_input('{"a":{"b":1}}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '1'
    body('rack.input'=>rack_input('[true, 2]'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '2'
  end

  it "raises for unsupported :wrap option" do
    proc do 
      app(:bare) do
        plugin(:json_parser, :wrap=>:foo, :content_type_regexp=>/\Aapplication\/json\b/i)
      end
    end.must_raise Roda::RodaError
  end

  it "supports :error_handler option" do
    app(:bare) do
      plugin(:json_parser, :error_handler=>proc{|r| r.halt [401, {}, ['bad']]}, :content_type_regexp=>/\Aapplication\/json\b/i)
      route do |r|
        r.params['a']['b'].to_s
      end
    end
    req('rack.input'=>rack_input('{"a":{"b":1}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal [401, {}, ['bad']]
  end

  it "works with bare POST" do
    app(:bare) do
      plugin(:json_parser, :error_handler=>proc{|r| r.halt [401, {}, ['bad']]}, :content_type_regexp=>/\Aapplication\/json\b/i)
      route do |r|
        (r.POST['a']['b'] + r.POST['a']['c']).to_s
      end
    end
    body('rack.input'=>rack_input('{"a":{"b":1,"c":2}}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '3'
  end

  it "supports :parser option" do
    app(:bare) do
      plugin(:json_parser, :parser=>method(:eval), :content_type_regexp=>/\Aapplication\/json\b/i)
      route do |r|
        r.params['a']['b'].to_s
      end
    end
    body('rack.input'=>rack_input("{'a'=>{'b'=>1}}"), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '1'
  end

  it "supports :include_request option" do
    app(:bare) do
      plugin(:json_parser,
        :include_request => true,
        :parser => lambda{|s,r| {'a'=>s, 'b'=>r.path_info}},
        :content_type_regexp=>/\Aapplication\/json\b/i)
      route do |r|
        "#{r.params['a']}:#{r.params['b']}"
      end
    end
    body('rack.input'=>rack_input('{}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '{}:/'
  end

  it "supports resetting :include_request option to false" do
    app(:bare) do
      plugin :json_parser, :include_request => true, :content_type_regexp=>/\Aapplication\/json\b/i
      plugin :json_parser, :include_request => false
      route do |r|
        r.params['a']['b'].to_s
      end
    end
    body('rack.input'=>rack_input('{"a":{"b":1}}'), 'CONTENT_TYPE'=>'application/json', 'REQUEST_METHOD'=>'POST').must_equal '1'
  end
end
