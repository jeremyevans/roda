require_relative "../spec_helper"

require 'uri'

describe 'response_attachment plugin' do
  before do
    app(:response_attachment) do |r|
      response.attachment r.path[1, 1000]
      'b'
    end
  end

  it 'sets the Content-Disposition header' do
    header(RodaResponseHeaders::CONTENT_DISPOSITION, '/foo/test.xml').must_equal 'attachment; filename="test.xml"'
    body.must_equal 'b'
  end

  it 'sets the Content-Disposition header with character set if filename contains characters that should be escaped' do
    filename = "/foo/a\u1023b.xml"
    app(:response_attachment) do |r|
      response.attachment filename
      'b'
    end

    header(RodaResponseHeaders::CONTENT_DISPOSITION).must_equal 'attachment; filename="a-b.xml"; filename*=UTF-8\'\'a%E1%80%A3b.xml'
    body.must_equal 'b'

    filename = "/foo/a\255\255b.xml".dup.force_encoding('ISO-8859-1')
    header(RodaResponseHeaders::CONTENT_DISPOSITION).must_equal 'attachment; filename="a-b.xml"; filename*=ISO-8859-1\'\'a%AD%ADb.xml'
    body.must_equal 'b'

    filename = "/foo/a\255\255b.xml".dup.force_encoding('BINARY')
    header(RodaResponseHeaders::CONTENT_DISPOSITION).must_equal 'attachment; filename="a-b.xml"'
    body.must_equal 'b'
  end

  it 'sets the Content-Disposition header even when a filename is not given' do
    app(:response_attachment) do |r|
      response.attachment
      'b'
    end
    header(RodaResponseHeaders::CONTENT_DISPOSITION, '/foo/test.xml').must_equal 'attachment'
  end

  it 'sets the Content-Type header' do
    header(RodaResponseHeaders::CONTENT_TYPE, '/test.xml').must_equal 'application/xml'
  end

  it 'does not modify the default Content-Type without a file extension' do
    header(RodaResponseHeaders::CONTENT_TYPE, '/README').must_equal 'text/html'
  end

  it 'should not modify the Content-Type if it is already set' do
    app(:response_attachment) do |r|
      response[RodaResponseHeaders::CONTENT_TYPE] = "foo"
      response.attachment r.path[1, 1000]
      'b'
    end

    header(RodaResponseHeaders::CONTENT_TYPE, '/README').must_equal 'foo'
  end
end

