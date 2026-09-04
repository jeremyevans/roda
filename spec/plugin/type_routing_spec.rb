# frozen_string_literal: true

require_relative "../spec_helper"

describe "type_routing plugin" do
  before do
    app(:type_routing) do |r|
      r.is 'a' do
        r.html{ "HTML: #{r.requested_type}" }
        r.json{ "JSON: #{r.requested_type}" }
        r.xml{ "XML: #{r.requested_type}" }
        "No match"
      end
    end
  end

  it "uses the file extension in the path" do
    body('/a').must_equal 'HTML: html'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a').must_equal 'text/html'

    body('/a.html').must_equal 'HTML: html'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a.html').must_equal 'text/html'

    body('/a.json').must_equal 'JSON: json'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a.json').must_equal 'application/json'

    body('/a.xml').must_equal 'XML: xml'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a.xml').must_equal 'application/xml'

    status('/a.yadda').must_equal 404
  end

  it "uses the Accept header value" do
    body('/a', 'HTTP_ACCEPT' => 'text/html').must_equal 'HTML: html'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a', 'HTTP_ACCEPT' => 'text/html').must_equal 'text/html'

    body('/a', 'HTTP_ACCEPT' => 'application/json').must_equal 'JSON: json'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a', 'HTTP_ACCEPT' => 'application/json').must_equal 'application/json'

    body('/a', 'HTTP_ACCEPT' => 'application/xml').must_equal 'XML: xml'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a', 'HTTP_ACCEPT' => 'application/xml').must_equal 'application/xml'

    body('/a', 'HTTP_ACCEPT' => 'some/thing').must_equal 'HTML: html'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a', 'HTTP_ACCEPT' => 'some/thing').must_equal 'text/html'
  end

  it "sets Vary header when using Accept header value" do
    body('/a', 'HTTP_ACCEPT' => 'text/html').must_equal 'HTML: html'
    header(RodaResponseHeaders::VARY, '/a', 'HTTP_ACCEPT' => 'text/html').must_equal 'Accept'
    header(RodaResponseHeaders::VARY, '/a', 'HTTP_ACCEPT' => 'image/png').must_equal 'Accept'

    app(:type_routing) do |r|
      response[RodaResponseHeaders::VARY] = 'User-Agent'
      r.is 'a' do
        r.html{ "HTML: #{r.requested_type}" }
        r.json{ "JSON: #{r.requested_type}" }
        "No match"
      end
    end
    body('/a', 'HTTP_ACCEPT' => 'application/json').must_equal 'JSON: json'
    header(RodaResponseHeaders::VARY, '/a', 'HTTP_ACCEPT' => 'application/json').must_equal 'User-Agent, Accept'
    header(RodaResponseHeaders::VARY, '/a', 'HTTP_ACCEPT' => 'image/png').must_equal 'User-Agent, Accept'
  end

  it "favors the file extension over the Accept header" do
    body('/a.json', 'HTTP_ACCEPT' => 'text/html').must_equal 'JSON: json'
    body('/a.xml', 'HTTP_ACCEPT' => 'application/json').must_equal 'XML: xml'
    body('/a.html', 'HTTP_ACCEPT' => 'application/xml').must_equal 'HTML: html'
  end

  it "works correctly in sub apps" do
    sup_app = app
    @app = Class.new(sup_app)
    app.route do |r|
      r.run(sup_app)
    end
    
    body('/a', 'HTTP_ACCEPT' => 'text/html').must_equal 'HTML: html'
    body('/a.json', 'HTTP_ACCEPT' => 'text/html').must_equal 'JSON: json'
    body('/a.xml', 'HTTP_ACCEPT' => 'application/json').must_equal 'XML: xml'
    body('/a.html', 'HTTP_ACCEPT' => 'application/xml').must_equal 'HTML: html'
  end

  it "works correctly in sub apps when sub app also handles extensions on empty paths" do
    sup_app = app
    @app = Class.new(sup_app)
    sup_app.route do |r|
      r.is do
        r.get do
          r.html { 'a' }
          r.json { '{b:1}' }
        end
      end

      r.on 'test' do
        r.get do
          r.html { 'c' }
          r.json { '{d:2}' }
        end
      end
    end
    app.route do |r|
      r.on "subpath" do
        r.run(sup_app)
      end
    end

    unless_lint do
      body('/subpath').must_equal 'a'
      body('/subpath.html').must_equal 'a'
      body('/subpath.json').must_equal '{b:1}'
    end
    body('/subpath/test').must_equal 'c'
    body('/subpath/test.html').must_equal 'c'
    body('/subpath/test.json').must_equal '{d:2}'
  end

  it "uses the default if neither file extension nor Accept header are given" do
    body('/a').must_equal 'HTML: html'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a').must_equal 'text/html'
  end
end

describe "type_routing plugin" do
  it "does not use the file extension if its disabled" do
    app(:bare) do
      plugin :type_routing, :use_extension => false

      route do |r|
        r.is 'a' do
          r.html{ "HTML" }
          r.json{ "JSON" }
        end
      end
    end

    status('/a.json').must_equal 404
    status('/a.html').must_equal 404
    body('/a', 'HTTP_ACCEPT' => 'text/html').must_equal 'HTML'
    body('/a', 'HTTP_ACCEPT' => 'application/json').must_equal 'JSON'
  end

  it "does not use the Accept header if its disabled" do
    app(:bare) do
      plugin :type_routing, :use_header => false

      route do |r|
        r.is 'a' do
          r.html{ "HTML" }
          r.json{ "JSON" }
        end
      end
    end

    body('/a', 'HTTP_ACCEPT' => 'text/html').must_equal 'HTML'
    body('/a', 'HTTP_ACCEPT' => 'application/json').must_equal 'HTML'
    body('/a.html', 'HTTP_ACCEPT' => 'application/json').must_equal 'HTML'
    body('/a.json', 'HTTP_ACCEPT' => 'text/html').must_equal 'JSON'
  end

  it "only eats known file extensions" do
    app(:bare) do
      plugin :type_routing

      route do |r|
        r.is 'a' do
          r.html{ "HTML" }
          r.json{ "JSON" }
          r.xml{ "XML" }
          raise "Mismatch!"
        end

        r.is 'a.jpg' do
          "Okay"
        end
      end
    end

    body('/a.html').must_equal 'HTML'
    body('/a.json').must_equal 'JSON'
    body('/a.xml').must_equal 'XML'
    body('/a.jpg').must_equal 'Okay'
  end

  it "uses custom data types" do
    app(:bare) do
      plugin :type_routing, :types => { :yaml => 'application/x-yaml' }

      route do |r|
        r.is 'a' do
          r.html{ "HTML" }
          r.yaml{ "YAML" }
          raise "Mismatch!"
        end
      end
    end

    body('/a.html').must_equal 'HTML'
    body('/a.yaml').must_equal 'YAML'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a.yaml').must_equal 'application/x-yaml'
  end

  it "handles response-specific type information when using custom types" do
    app(:bare) do
      plugin :type_routing, :exclude=>:html, :default_type=>:json, :types => { :html => 'text/html; charset=utf-8' }

      route do |r|
        r.is 'a' do
          r.json{ "JSON" }
          r.html{ "HTML" }
          raise "Mismatch!"
        end
      end
    end

    body('/a').must_equal 'JSON'
    body('/a.html').must_equal 'HTML'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a.html').must_equal 'text/html; charset=utf-8'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a', 'HTTP_ACCEPT' => 'text/html').must_equal 'text/html; charset=utf-8'
  end

  it "Handle nil content type when using custom types" do
    app(:bare) do
      plugin :type_routing, :exclude=>:html, :default_type=>:json, :types => { :html => nil}

      route do |r|
        r.is 'a' do
          r.html{ "HTML" }
          r.json{ "JSON" }
          raise "Mismatch!"
        end
      end
    end

    body('/a').must_equal 'JSON'
    body('/a.html').must_equal 'HTML'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a.html').must_equal 'text/html'
    header(RodaResponseHeaders::CONTENT_TYPE, '/a', 'HTTP_ACCEPT' => 'text/html').must_equal 'application/json'
  end

  it "uses custom default type" do
    app(:bare) do
      plugin :type_routing, :default_type => :json

      route do |r|
        r.is 'a' do
          r.html{ "HTML" }
          r.json{ "JSON" }
          raise "Mismatch!"
        end
      end
    end

    body('/a').must_equal 'JSON'
    body('/a.html').must_equal 'HTML'
    body('/a.json').must_equal 'JSON'
  end

  it "supports nil default type" do
    app(:bare) do
      plugin :type_routing, :default_type => nil

      route do |r|
        r.is 'a' do
          r.html{ "HTML" }
          r.json{ "JSON" }
          "None"
        end
      end
    end

    body('/a').must_equal 'None'
    body('/a.html').must_equal 'HTML'
    body('/a.json').must_equal 'JSON'
  end

  it "excludes given types" do
    app(:bare) do
      plugin :type_routing, :exclude => [ :xml ]

      route do |r|
        r.is 'a' do
          r.html{ "HTML" }
          r.json{ "JSON" }
          r.xml{ raise "Mismatch!" }
          raise "Mismatch"
        end
      end
    end

    body('/a.html').must_equal 'HTML'
    body('/a.json').must_equal 'JSON'
    status('/a.xml').must_equal 404

    body('/a', 'HTTP_ACCEPT' => 'text/xml').must_equal 'HTML'
    body('/a', 'HTTP_ACCEPT' => 'application/json').must_equal 'JSON'
    body('/a', 'HTTP_ACCEPT' => 'text/xml').must_equal 'HTML'
    body('/a', 'HTTP_ACCEPT' => 'application/xml').must_equal 'HTML'
  end

  it "handles loading the plugin multiple times correctly" do
    app(:bare) do
      plugin :type_routing, :default_type => :json
      plugin :type_routing

      route do |r|
        r.is 'a' do
          r.html{ "HTML" }
          r.json{ "JSON" }
          raise "Mismatch!"
        end
      end
    end

    body('/a').must_equal 'JSON'
    body('/a.html').must_equal 'HTML'
    body('/a.json').must_equal 'JSON'
  end

  it "removes the handled part from r.remaining_path" do
    app(:bare) do
      plugin :type_routing

      route do |r|
        r.is 'a' do
          r.html{ r.remaining_path }
        end
      end
    end

    body('/a.html').must_equal ''
  end

  it "overrides r.real_remaining_path correctly" do
    app(:bare) do
      plugin :type_routing

      route do |r|
        r.is 'a' do
          r.html{ r.real_remaining_path }
        end
      end
    end

    body('/a.html').must_equal '.html'
  end

  it "takes the longest file extension first, when ambiguous" do
    app(:bare) do
      plugin :type_routing, :types => {
        :gz => 'application/octet-stream',
        :'tar.gz' => 'application/octet-stream',
      }

      route do |r|
        r.is 'a' do
          r.on_type(:gz) { 'GZ' }
          r.on_type(:'tar.gz') { 'TAR.GZ' }
          "NO"
        end
      end
    end

    body('/a').must_equal "NO"
    body('/a.gz').must_equal 'GZ'
    body('/a.tar.gz').must_equal 'TAR.GZ'
  end
end
