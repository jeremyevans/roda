require_relative "../spec_helper"

describe "disallow_multipart_parsing plugin" do 
  it "disallows parsing of multipart request bodies" do
    app do |r|
      r.POST
      r.POST.keys.join("-")
    end

    request_body = rack_input("------WebKitFormBoundarymwHIM9XjTTVHn3YP\r\nContent-Disposition: form-data; name=\"foo\"; filename=\"bar.txt\"\r\nContent-Type: text/plain\r\n\r\nfoo\n\r\n------WebKitFormBoundarymwHIM9XjTTVHn3YP--\r\n")

    h = {
      'rack.input'=>request_body,
      'CONTENT_TYPE'=>'multipart/form-data; boundary=----WebKitFormBoundarymwHIM9XjTTVHn3YP',
      'CONTENT_LENGTH'=>request_body.string.bytesize.to_s,
      'REQUEST_METHOD'=>'POST'
    }
    body(h).must_equal "foo"
    app.plugin :disallow_multipart_parsing
    request_body.rewind
    proc{body(h)}.must_raise Roda::RodaPlugins::DisallowMultipartParsing::Error

    request_body = rack_input("------WebKitFormBoundarymwHIM9XjTTVHn3YP\r\nContent-Disposition: form-data; name=\"foo\"\r\nContent-Type: text/plain\r\n\r\nfoo\n\r\n------WebKitFormBoundarymwHIM9XjTTVHn3YP--\r\n")
    h = {
      'rack.input'=>request_body,
      'CONTENT_TYPE'=>'multipart/form-data; boundary=----WebKitFormBoundarymwHIM9XjTTVHn3YP',
      'CONTENT_LENGTH'=>request_body.string.bytesize.to_s,
      'REQUEST_METHOD'=>'POST'
    }
    proc{body(h)}.must_raise Roda::RodaPlugins::DisallowMultipartParsing::Error

    request_body = rack_input("foo=foo")
    h = {
      'rack.input'=>request_body,
      'CONTENT_TYPE'=>'application/x-www-form-urlencoded',
      'CONTENT_LENGTH'=>request_body.string.bytesize.to_s,
      'REQUEST_METHOD'=>'POST'
    }
    body(h).must_equal "foo"

    h.delete("CONTENT_TYPE")
    request_body.rewind
    body(h).must_equal "foo"
  end
end
