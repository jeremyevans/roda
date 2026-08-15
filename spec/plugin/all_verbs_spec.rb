require_relative "../spec_helper"

describe "all_verbs plugin" do 
  it "adds method for each http verb" do
    app(:all_verbs) do |r|
      r.delete{'d'}
      r.head{''}
      r.options{'o'}
      r.patch{'pa'}
      r.put{'pu'}
      r.trace{'t'}
      if Rack::Request.method_defined?(:link?)
        r.link{'l'}
        r.unlink{'u'}
      end
      if Rack::Request.method_defined?(:query?)
        r.query{'q'}
      end
    end

    body('REQUEST_METHOD'=>'DELETE').must_equal 'd'
    body('REQUEST_METHOD'=>'HEAD').must_equal ''
    body('REQUEST_METHOD'=>'OPTIONS').must_equal 'o'
    body('REQUEST_METHOD'=>'PATCH').must_equal 'pa'
    body('REQUEST_METHOD'=>'PUT').must_equal 'pu'
    body('REQUEST_METHOD'=>'TRACE').must_equal 't'
    if Rack::Request.method_defined?(:link?)
      body('REQUEST_METHOD'=>'LINK').must_equal 'l'
      body('REQUEST_METHOD'=>'UNLINK').must_equal 'u'
    end
    if Rack::Request.method_defined?(:query?)
      body('REQUEST_METHOD'=>'QUERY').must_equal 'q'
    end
  end
end
