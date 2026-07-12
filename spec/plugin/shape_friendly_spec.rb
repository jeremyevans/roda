require_relative "../spec_helper"

describe "shape_friendly plugin" do 
  def check_ivs
    unless ENV["SHAPE_FRIENDLY"]
      body.must_equal <<END
@_request,@_response
@captures,@env,@remaining_path,@scope
@body,@headers,@length
END
      app.plugin :shape_friendly
    end

    body.must_equal <<END
@_request,@_response
@captures,@env,@remaining_path,@scope
@body,@headers,@length,@status
END
    app.plugin :common_logger, StringIO.new
    body.must_equal <<END
@_request,@_request_timer,@_response
@captures,@env,@remaining_path,@scope
@body,@headers,@length,@status
END
    app.plugin :branch_locals
    body.must_equal <<END
@_layout_locals,@_request,@_request_timer,@_response,@_view_locals
@captures,@env,@remaining_path,@scope
@body,@headers,@length,@status
END
    app.plugin :content_security_policy
    body.must_equal <<END
@_layout_locals,@_request,@_request_timer,@_response,@_view_locals
@captures,@env,@remaining_path,@scope
@body,@content_security_policy,@headers,@length,@skip_content_security_policy,@status
END
    app.plugin :not_allowed
    body.must_equal <<END
@_layout_locals,@_request,@_request_timer,@_response,@_view_locals
@_is_verbs,@captures,@env,@remaining_path,@scope
@body,@content_security_policy,@headers,@length,@skip_content_security_policy,@status
END
    # Test with plugin module instead of symbol and :scope_instance_variables option
    app.plugin Roda::RodaPlugins::ShapeFriendly, :scope_instance_variables=>[:@app1, :@app2]
    body.must_equal <<END
@_layout_locals,@_request,@_request_timer,@_response,@_view_locals,@app1,@app2
@_is_verbs,@captures,@env,@remaining_path,@scope
@body,@content_security_policy,@headers,@length,@skip_content_security_policy,@status
END
  end

  it "makes the app shape friendly" do
    app do |r|
      <<END
#{instance_variables.sort.join(",")}
#{r.instance_variables.sort.join(",")}
#{response.instance_variables.sort.join(",")}
END
    end
    check_ivs
    sf = Roda::RodaPlugins::ShapeFriendly
    app.ancestors.include?(sf::OptimizedInstanceMethods).must_equal true
    app::RodaRequest.ancestors.include?(sf::OptimizedRequestMethods).must_equal true
    app::RodaResponse.ancestors.include?(sf::OptimizedResponseMethods).must_equal true
  end

  it "handles already overridden initialize methods" do
    app(:bare) do
      define_method(:initialize){|env| super(env)}
      self::RodaRequest.send(:define_method, :initialize){|scope, env| super(scope, env)}
      self::RodaResponse.send(:define_method, :initialize){super()}

      route do |r|
        <<END
#{instance_variables.sort.join(",")}
#{r.instance_variables.sort.join(",")}
#{response.instance_variables.sort.join(",")}
END
      end
    end
    check_ivs
    sf = Roda::RodaPlugins::ShapeFriendly
    app.ancestors.include?(sf::UnoptimizedInstanceMethods).must_equal true
    app::RodaRequest.ancestors.include?(sf::UnoptimizedRequestMethods).must_equal true
    app::RodaResponse.ancestors.include?(sf::UnoptimizedResponseMethods).must_equal true
  end

  it "raises for invalid instance variable" do
    app{|_|}
    proc{app.plugin :shape_friendly, :scope_instance_variables=>[:bad]}.must_raise Roda::RodaError
  end

  it "does not include nil instance variables in inspect" do
    app(:shape_friendly) do |_|
      @a = nil
      inspect
    end
    body.wont_include("@a=nil")
  end if RUBY_VERSION >= "4"
end
