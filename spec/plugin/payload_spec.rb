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
end
