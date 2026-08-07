require_relative "../spec_helper"

describe "delegate plugin" do 
  it "adds request_delegate and response_delegate class methods for delegating" do
    app(:bare) do 
      plugin :delegate
      request_delegate :root
      response_delegate :headers

      def self.a; 'foo'; end
      class_delegate :a

      route do |_|
        root do
          headers[RodaResponseHeaders::CONTENT_TYPE] = a
        end
      end
    end
    
    header(RodaResponseHeaders::CONTENT_TYPE).must_equal 'foo'
    status('/foo').must_equal 404
  end
end
