require File.expand_path("spec_helper", File.dirname(File.dirname(__FILE__)))

describe "symbolized_params plugin" do
  it "exposes the symbolized version of request params via params method" do
    app(:symbolized_params) do |r|
      r.on do
        params.inspect
      end
    end

    body('QUERY_STRING'=>'a=2&b[][c]=3', 'rack.input'=>StringIO.new).should == '{:a=>"2", :b=>[{:c=>"3"}]}'
  end
end
