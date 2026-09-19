require_relative "../spec_helper"

describe "request_aref plugin" do 
  def request_aref_app(value)
    warning = @warning = String.new('')
    app(:bare) do
      plugin :request_aref, value
      self::RodaRequest.class_exec do
        define_method(:warn){|s| warning.replace(s)}
        private :warn
      end
      route do |r|
        r.get('set'){r['b'] = 'c'; r.params['b']}
        r['a']
      end
    end
  end

  def aref_body
    body("QUERY_STRING" => 'a=d', 'rack.input'=>rack_input)
  end

  def aset_body
    body('/set', "QUERY_STRING" => 'a=d', 'rack.input'=>rack_input)
  end

  it "allows if given the :allow option" do
    request_aref_app(:allow)
    aref_body.must_equal 'd'
    @warning.must_equal ''
    aset_body.must_equal 'c'
    @warning.must_equal ''
  end

  it "warns if given the :warn option" do
    request_aref_app(:warn)
    aref_body.must_equal 'd'
    @warning.must_include('#[] is deprecated, use #params.[] instead')
    aset_body.must_equal 'c'
    @warning.must_include('#[]= is deprecated, use #params.[]= instead')
  end

  it "raises if given the :raise option" do
    request_aref_app(:raise)
    proc{aref_body}.must_raise Roda::RodaPlugins::RequestAref::Error
    @warning.must_equal ''
    proc{aset_body}.must_raise Roda::RodaPlugins::RequestAref::Error
    @warning.must_equal ''
  end

  it "raises when loading plugin if given other option" do
    proc{request_aref_app(:r)}.must_raise Roda::RodaError
  end
end
