require_relative "../spec_helper"

describe "public plugin" do 
  it "adds r.public for serving static files from public folder" do
    app(:bare) do
      plugin :public, :root=>'spec/views'

      route do |r|
        r.public

        r.on 'static' do
          r.public
        end
      end
    end

    status("/about/_test.erb\0").must_equal 404
    status("/output/file").must_equal 404
    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/static/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/foo/.././/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it "respects the application's :root option" do
    app(:bare) do
      opts[:root] = File.expand_path('../../', __FILE__)
      plugin :public, :root=>'views'

      route do |r|
        r.public
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it "keeps existing :root option if loaded a second time" do
    app(:bare) do
      plugin :public, :root=>'spec/views'
      plugin :public

      route do |r|
        r.public
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header('Content-Type', '/about/_test.erb').must_equal 'text/plain'
    header('X-Foo', '/about/_test.erb').must_be_nil
  end

  it "support :headers options for custom headers" do
    app(:bare) do
      plugin :public, :root=>'spec/views', :headers=>{'X-Foo' => 'bar'}

      route do |r|
        r.public
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header('Content-Type', '/about/_test.erb').must_equal 'text/plain'
    header('X-Foo', '/about/_test.erb').must_equal 'bar'
  end

  it "support :default_mime options for default mime type" do
    app(:bare) do
      plugin :public, :root=>'spec/views', :default_mime=>'foo/bar'

      route do |r|
        r.public
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header('Content-Type', '/about/_test.erb').must_equal 'foo/bar'
    header('X-Foo', '/about/_test.erb').must_be_nil
  end

  it "assumes public directory as default :root option" do
    app(:public){}
    app.opts[:public_root].must_equal File.expand_path('public')
  end

  it "handles serving gzip files in gzip mode if client supports gzip" do
    app(:bare) do
      plugin :public, :root=>'spec/views', :gzip=>true

      route do |r|
        r.public
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header('Content-Encoding', '/about/_test.erb').must_be_nil

    body('/about.erb').must_equal File.read('spec/views/about.erb')
    header('Content-Encoding', '/about.erb').must_be_nil

    body('/about/_test.erb', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip').must_equal File.binread('spec/views/about/_test.erb.gz')
    h = req('/about/_test.erb', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip')[1]
    h['Content-Encoding'].must_equal 'gzip'
    h['Content-Type'].must_equal 'text/plain'

    body('/about/_test.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip').must_equal File.binread('spec/views/about/_test.css.gz')
    h = req('/about/_test.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip')[1]
    h['Content-Encoding'].must_equal 'gzip'
    h['Content-Type'].must_equal 'text/css'

    s, h, b = req('/about/_test.css', 'HTTP_IF_MODIFIED_SINCE'=>h["Last-Modified"], 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip')
    s.must_equal 304
    h['Content-Encoding'].must_be_nil
    h['Content-Type'].must_be_nil
    b.must_equal []
  end

  it "handles serving brotli files in brotli mode if client supports brotli and falls back gracefully" do
    app(:bare) do
      plugin :public, :root=>'spec/views', :gzip=>true, :brotli=>true

      route do |r|
        r.public
      end
    end
    
    body('/about/_test2.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip, br').must_equal File.binread('spec/views/about/_test2.css.br')
    h = req('/about/_test2.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip, br')[1]
    h['Content-Encoding'].must_equal 'br'
    h['Content-Type'].must_equal 'text/css'

    body('/about/_test2.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip').must_equal File.binread('spec/views/about/_test2.css.gz')
    h = req('/about/_test2.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip')[1]
    h['Content-Encoding'].must_equal 'gzip'
    h['Content-Type'].must_equal 'text/css'

    body('/about/_test2.css').must_equal File.binread('spec/views/about/_test2.css')
    h = req('/about/_test2.css')[1]
    h['Content-Encoding'].must_be_nil
    h['Content-Type'].must_equal 'text/css'

    body('/about/_test.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip, br').must_equal File.binread('spec/views/about/_test.css.gz')
    h = req('/about/_test.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip, br')[1]
    h['Content-Encoding'].must_equal 'gzip'
    h['Content-Type'].must_equal 'text/css'
  end

  it "does not handle non-GET requests" do
    app(:bare) do
      plugin :public, :root=>'spec/views'

      route do |r|
        r.public
      end
    end

    status("/about/_test.erb", "REQUEST_METHOD"=>"POST").must_equal 404
  end

  it "allows pretty URLs for HTML files" do
    app(:bare) do
      plugin :public, :root=>'spec/views', :pretty_urls=>true

      route do |r|
        r.public
      end
    end

    body('/output/file').must_equal File.read('spec/views/output/file.html')
    body('/output/file/').must_equal File.read('spec/views/output/file.html')
    body('/output/second_file').must_equal File.read('spec/views/output/second_file/index.html')
    body('/output/second_file/').must_equal File.read('spec/views/output/second_file/index.html')
    body('/output/third_file').must_equal File.read('spec/views/output/third_file/index.html')
    body('/output/third_file.html').must_equal File.read('spec/views/output/third_file.html')
  end
end
