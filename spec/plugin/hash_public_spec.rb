require_relative '../spec_helper'

describe 'hash_public plugin' do
  it 'adds r.hash_public for serving static files with content-hash-based paths' do
    app(:bare) do
      plugin :hash_public, root: 'spec/views'

      route do |r|
        r.hash_public
      end
    end

    status("/about/_test.erb\0").must_equal 404
    status('/about/_test.erb').must_equal 404
    status("/static/a/about/_test.erb\0").must_equal 404
    body('/static/a/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it 'supports the :prefix option' do
    app(:bare) do
      plugin :hash_public, root: 'spec/views', prefix: 'foo'

      route do |r|
        r.hash_public
      end
    end

    body('/foo/a/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it 'returns the correct hash_path with content hash' do
    app(:bare) do
      plugin :hash_public, root: 'spec/plugin'

      route do |r|
        r.hash_public
        hash_path('../views/about/_test.erb')
      end
    end

    body.must_equal "/static/q12-OV-wZhMcEiJj7V60pITfJeGWgmIvBpSjMjef4UY/../views/about/_test.erb"
    status('/static/a/../views/about/_test.erb').must_equal 404
  end

  it "respects the application's :root option" do
    app(:bare) do
      opts[:root] = File.expand_path('..', File.dirname(__FILE__))
      plugin :hash_public, root: 'views'

      route do |r|
        r.hash_public
      end
    end

    body('/static/a/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it 'handles serving gzip files in gzip mode if client supports gzip' do
    app(:bare) do
      plugin :hash_public, root: 'spec/views', gzip: true

      route do |r|
        r.hash_public
      end
    end

    body('/static/a/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header(RodaResponseHeaders::CONTENT_ENCODING, '/about/_test.erb').must_be_nil

    body('/static/a/about.erb').must_equal File.read('spec/views/about.erb')
    header(RodaResponseHeaders::CONTENT_ENCODING, '/about.erb').must_be_nil

    body('/static/a/about/_test.erb',
         'HTTP_ACCEPT_ENCODING' => 'deflate, gzip').must_equal File.binread('spec/views/about/_test.erb.gz')
    h = req('/static/a/about/_test.erb', 'HTTP_ACCEPT_ENCODING' => 'deflate, gzip')[1]
    h[RodaResponseHeaders::CONTENT_ENCODING].must_equal 'gzip'
    h[RodaResponseHeaders::CONTENT_TYPE].must_equal 'text/plain'

    body('/static/a/about/_test.css',
         'HTTP_ACCEPT_ENCODING' => 'deflate, gzip').must_equal File.binread('spec/views/about/_test.css.gz')
    h = req('/static/a/about/_test.css', 'HTTP_ACCEPT_ENCODING' => 'deflate, gzip')[1]
    h[RodaResponseHeaders::CONTENT_ENCODING].must_equal 'gzip'
    h[RodaResponseHeaders::CONTENT_TYPE].must_equal 'text/css'
  end

  it 'returns 404 for non-GET requests' do
    app(:bare) do
      plugin :hash_public, root: 'spec/views', prefix: 'foo'

      route do |r|
        r.hash_public
      end
    end

    status('/foo/a/about/_test.erb', 'REQUEST_METHOD' => 'POST').must_equal 404
  end

  it 'supports the :length option to truncate the hash' do
    app(:bare) do
      plugin :hash_public, root: 'spec/plugin', length: 16

      route do |r|
        r.hash_public
        hash_path('../views/about/_test.erb')
      end
    end

    body.must_equal "/static/q12-OV-wZhMcEiJj/../views/about/_test.erb"
  end

  it 'caches hash values for the same file' do
    app(:bare) do
      plugin :hash_public, root: 'spec/plugin'

      route do |r|
        r.hash_public
        hash_path('../views/about/_test.erb')
      end
    end

    result1 = body
    result2 = body
    result1.must_equal result2
  end
end
