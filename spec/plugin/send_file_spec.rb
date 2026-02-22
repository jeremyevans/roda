require_relative "../spec_helper"

require 'uri'

describe 'send_file plugin' do
  before do
    file = @file = 'spec/assets/css/raw.css'
    @content = File.read(@file)
    app(:send_file) do |r|
      send_file file, env['rack.OPTS'] || {}
    end
  end

  it "sends the contents of the file" do
    status.must_equal 200
    body.must_equal @content
  end

  it "returns response body implementing to_path" do
    req[2].to_path.must_equal @file
  end if !ENV['LINT'] || Rack.release >= '3'

  it 'sets the Content-Type response header if a mime-type can be located' do
    header(RodaResponseHeaders::CONTENT_TYPE).must_equal 'text/css'
  end

  it 'sets the Content-Type response header if type option is set to a file extension' do
    header(RodaResponseHeaders::CONTENT_TYPE, 'rack.OPTS'=>{:type => 'html'}).must_equal 'text/html'
  end

  it 'sets the Content-Type response header if type option is set to a mime type' do
    header(RodaResponseHeaders::CONTENT_TYPE, 'rack.OPTS'=>{:type => 'application/octet-stream'}).must_equal 'application/octet-stream'
  end

  it 'sets the Content-Length response header' do
    header(RodaResponseHeaders::CONTENT_LENGTH).must_equal @content.length.to_s
  end

  it 'sets the Last-Modified response header' do
    header(RodaResponseHeaders::LAST_MODIFIED).must_equal File.mtime(@file).httpdate
  end

  it 'allows passing in a different Last-Modified response header with :last_modified' do
    time = Time.now
    @app.plugin :caching
    header(RodaResponseHeaders::LAST_MODIFIED, 'rack.OPTS'=>{:last_modified => time}).must_equal time.httpdate
  end

  it "returns a 404 when not found" do
    app(:send_file) do |r|
      send_file 'this-file-does-not-exist.txt'
    end
    status.must_equal 404
  end

  it "does not set the Content-Disposition header by default" do
    header(RodaResponseHeaders::CONTENT_DISPOSITION).must_be_nil
  end

  it "sets the Content-Disposition header when :disposition set to 'attachment'" do
    header(RodaResponseHeaders::CONTENT_DISPOSITION, 'rack.OPTS'=>{:disposition => 'attachment'}).must_equal 'attachment; filename="raw.css"'
  end

  it "does not set add a file name if filename is false" do
    header(RodaResponseHeaders::CONTENT_DISPOSITION, 'rack.OPTS'=>{:disposition => 'inline', :filename=>false}).must_equal 'inline'
  end

  it "sets the Content-Disposition header when :disposition set to 'inline'" do
    header(RodaResponseHeaders::CONTENT_DISPOSITION, 'rack.OPTS'=>{:disposition => 'inline'}).must_equal 'inline; filename="raw.css"'
  end

  it "sets the Content-Disposition header when :filename provided" do
    header(RodaResponseHeaders::CONTENT_DISPOSITION, 'rack.OPTS'=>{:filename => 'foo.txt'}).must_equal 'attachment; filename="foo.txt"'
  end

  it 'allows setting a custom status code' do
    status('rack.OPTS'=>{:status=>201}).must_equal 201
  end

  it "is able to send files with unknown mime type" do
    header(RodaResponseHeaders::CONTENT_TYPE, 'rack.OPTS'=>{:type => '.foobar'}).must_equal 'application/octet-stream'
  end

  it "does not override Content-Type if already set and no explicit type is given" do
    file = @file
    app(:send_file) do |r|
      response[RodaResponseHeaders::CONTENT_TYPE] = "image/png"
      send_file file
    end
    header(RodaResponseHeaders::CONTENT_TYPE).must_equal 'image/png'
  end

  it "does override Content-Type even if already set, if explicit type is given" do
    file = @file
    app(:send_file) do |r|
      response[RodaResponseHeaders::CONTENT_TYPE] = "image/png"
      send_file file, :type => :gif
    end
    header(RodaResponseHeaders::CONTENT_TYPE).must_equal 'image/gif'
  end
end
