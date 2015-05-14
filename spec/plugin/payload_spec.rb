require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

describe "payload plugin" do
  # random 5 character String
  let(:string) { (0...5).map { (65 + rand(26)).chr }.join }

  it "Reads the contents of the `rack.input` object and returns it" do
    app(:payload) do |r|
      r.on do
        payload
      end
    end

    body('QUERY_STRING'=>'a=2&b=3', 'rack.input'=>StringIO.new(string)).must_equal string
  end

  describe "No payload content" do
    it "returns `nil` and doesn't raise an error" do
      app(:payload) do |r|
        r.on do
          payload
        end
      end

      body('QUERY_STRING'=>'a=2&b=3', 'rack.input'=>StringIO.new).must_equal ''
    end
  end

  describe "`Roda::RodaPlugins::Json` plugin is loaded on the app" do
    before do
      app(:bare) do |r|
        plugin :payload
        plugin :json_parser

        route do |r|
          r.on do
            payload.to_s
          end
        end
      end
    end

    describe "payload IS in JSON format" do
      let(:obj) { {'key' => string} }
      let(:json_string) { JSON.dump(obj) }

      it "should parse the JSON and return the parsed object" do
        body('QUERY_STRING'=>'a=2', 'rack.input'=>StringIO.new(json_string), 'CONTENT_TYPE'=>'text/json').must_equal obj.to_s
      end
    end

    describe "payload IS NOT in JSON format (but content_type mistakenly says it is)" do
      it "should just return the raw String contents" do
        body('QUERY_STRING'=>'a=2', 'rack.input'=>StringIO.new(string), 'CONTENT_TYPE'=>'text/json').must_equal string
      end
    end
  end
end
