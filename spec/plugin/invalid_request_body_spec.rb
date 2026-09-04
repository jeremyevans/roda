require_relative "../spec_helper"

describe "invalid_request_body plugin" do 
  def invalid_request_body_app(*args, &block)
    app(:bare) do
      plugin :invalid_request_body, *args, &block
      route{|r| r.POST.to_a.inspect}
    end
  end
  content_type = 'multipart/form-data; boundary=foobar'
  valid_body = "--foobar\r\nContent-Disposition: form-data; name=\"x\"\r\n\r\ny\r\n--foobar--"
  define_method :valid_request_hash do
    {"REQUEST_METHOD"=>'POST', 'CONTENT_TYPE'=>content_type, 'CONTENT_LENGTH'=>valid_body.bytesize.to_s, 'rack.input'=>rack_input(valid_body)}
  end
  define_method :invalid_request_hash do
    {"REQUEST_METHOD"=>'POST', 'CONTENT_TYPE'=>content_type, 'CONTENT_LENGTH'=>'100', 'rack.input'=>rack_input}
  end

  it "supports :empty_400 plugin argument" do
    invalid_request_body_app(:empty_400)
    body(valid_request_hash).must_equal '[["x", "y"]]'
    req(invalid_request_hash).must_equal [400, {RodaResponseHeaders::CONTENT_TYPE=>'text/html', RodaResponseHeaders::CONTENT_LENGTH=>'0'}, []]
  end

  it "supports :empty_hash plugin argument" do
    invalid_request_body_app(:empty_hash)
    body(valid_request_hash).must_equal '[["x", "y"]]'
    req(invalid_request_hash).must_equal [200, {RodaResponseHeaders::CONTENT_TYPE=>'text/html', RodaResponseHeaders::CONTENT_LENGTH=>'2'}, ['[]']]
  end

  it "supports :raise plugin argument" do
    invalid_request_body_app(:raise)
    body(valid_request_hash).must_equal '[["x", "y"]]'
    proc{req(invalid_request_hash)}.must_raise Roda::RodaPlugins::InvalidRequestBody::Error
  end

  it "reraises Roda errors, not swallowing errors raised by disallow_file_uploads plugin" do
    invalid_request_body_app(:raise)
    app.plugin :disallow_file_uploads
    body(valid_request_hash).must_equal '[["x", "y"]]'
    file_upload_body = "--foobar\r\ncontent-disposition: form-data; name=\"f\"; filename=\"t\"\r\n\r\ny\r\n--foobar--\r\n"
    proc{req(invalid_request_hash.merge('CONTENT_LENGTH'=>file_upload_body.bytesize.to_s, 'rack.input'=>rack_input(file_upload_body)))}.must_raise Roda::RodaPlugins::DisallowFileUploads::Error
  end if Rack.release >= '1.6'

  it "supports plugin block argument" do
    invalid_request_body_app{|e| {'y'=>"x"}}
    body(valid_request_hash).must_equal '[["x", "y"]]'
    body(invalid_request_hash).must_equal '[["y", "x"]]'
  end

  it "raises Error if configuring plugin with invalid plugin argument" do
    proc{invalid_request_body_app(:foo)}.must_raise Roda::RodaError
  end

  it "raises Error if configuring plugin with block and regular argument" do
    proc{invalid_request_body_app(:raise){}}.must_raise Roda::RodaError
  end

  it "raises Error if configuring plugin without block or regular argument" do
    proc{invalid_request_body_app}.must_raise Roda::RodaError
  end
end
