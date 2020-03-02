require_relative "../spec_helper"

describe "exception_page plugin" do 
  def ep_app(&block)
    app(:exception_page) do |r|
      raise "foo" rescue block ? instance_exec($!, &block) : exception_page($!)
    end
  end

  def req(path = '/', headers={})
    if path.is_a?(Hash)
      super({'rack.input'=>StringIO.new}.merge(path))
    else
      super(path, {'rack.input'=>StringIO.new}.merge(headers))
    end
  end

  it "returns HTML page with exception information if text/html is accepted" do
    ep_app
    s, h, body = req('HTTP_ACCEPT'=>'text/html')

    s.must_equal 200
    h['Content-Type'].must_equal 'text/html'
    body = body.join
    body.must_include "<title>RuntimeError at /"
    body.must_include "<h1>RuntimeError at /</h1>"
    body.must_include "<h2>foo</h2>"
    body.must_include __FILE__
    body.must_include "No GET data"
    body.must_include "No POST data"
    body.must_include "No cookie data"
    body.must_include "Rack ENV"
    body.must_include "HTTP_ACCEPT"
    body.must_include "text/html"
    body.must_include "table td.code"
    body.must_include "function toggle()"
    body.wont_include "\"/exception_page.css\""
    body.wont_include "\"/exception_page.js\""

    s, h, body = req('HTTP_ACCEPT'=>'text/html', 'REQUEST_METHOD'=>'POST', 'rack.input'=>StringIO.new('(%bad-params%)'))
    s.must_equal 200
    h['Content-Type'].must_equal 'text/html'
    body.join.must_include "Invalid POST data"

    size = body.size
    ep_app{|e| exception_page(e, :context=>10)}
    body('HTTP_ACCEPT'=>'text/html').size.must_be :>, size

    ep_app{|e| exception_page(e, :assets=>true, :context=>0)}
    body = body('HTTP_ACCEPT'=>'text/html')
    body.wont_include "table td.code"
    body.wont_include "function toggle()"
    body.must_include "\"/exception_page.css\""
    body.must_include "\"/exception_page.js\""

    ep_app{|e| exception_page(e, :assets=>"/static", :context=>0)}
    body = body('HTTP_ACCEPT'=>'text/html')
    body.wont_include "table td.code"
    body.wont_include "function toggle()"
    body.must_include "\"/static/exception_page.css\""
    body.must_include "\"/static/exception_page.js\""

    ep_app{|e| exception_page(e, :css_file=>"/foo.css", :context=>0)}
    body = body('HTTP_ACCEPT'=>'text/html')
    body.wont_include "table td.code"
    body.must_include "function toggle()"
    body.must_include "\"/foo.css\""

    ep_app{|e| exception_page(e, :js_file=>"/foo.js", :context=>0)}
    body = body('HTTP_ACCEPT'=>'text/html')
    body.must_include "table td.code"
    body.wont_include "function toggle()"
    body.must_include "\"/foo.js\""

    ep_app{|e| exception_page(e, :assets=>false, :context=>0)}
    body = body('HTTP_ACCEPT'=>'text/html')
    body.wont_include "table td.code"
    body.wont_include "function toggle()"
    body.wont_include "\"/exception_page.css\""
    body.wont_include "\"/exception_page.js\""

    ep_app{|e| exception_page(e, :assets=>false, :css_file=>"/foo.css", :context=>0)}
    body = body('HTTP_ACCEPT'=>'text/html')
    body.wont_include "table td.code"
    body.wont_include "function toggle()"
    body.must_include "\"/foo.css\""

    ep_app{|e| exception_page(e, :assets=>false, :js_file=>"/foo.js", :context=>0)}
    body = body('HTTP_ACCEPT'=>'text/html')
    body.wont_include "table td.code"
    body.wont_include "function toggle()"
    body.must_include "\"/foo.js\""

    ep_app{|e| exception_page(e, :css_file=>false, :context=>0)}
    body = body('HTTP_ACCEPT'=>'text/html')
    body.wont_include "table td.code"
    body.must_include "function toggle()"
    body.wont_include "\"/exception_page.css\""
    body.wont_include "\"/exception_page.js\""

    ep_app{|e| exception_page(e, :js_file=>false, :context=>0)}
    body = body('HTTP_ACCEPT'=>'text/html')
    body.must_include "table td.code"
    body.wont_include "function toggle()"
    body.wont_include "\"/exception_page.css\""
    body.wont_include "\"/exception_page.js\""
  end

  it "returns plain text page with exception information if text/html is not accepted" do
    ep_app
    s, h, body = req

    s.must_equal 200
    h['Content-Type'].must_equal 'text/plain'
    body = body.join
    first, *bt = body.split("\n")
    first.must_equal "RuntimeError: foo"
    bt.first.must_include __FILE__
  end

  it "returns JSON with exception information if :json information is used" do
    ep_app{|e| exception_page(e, :json=>true)}
    @app.plugin :json
    s, h, body = req

    s.must_equal 200
    h['Content-Type'].must_equal 'application/json'
    hash = JSON.parse(body.join)
    bt = hash["exception"].delete("backtrace")
    hash.must_equal("exception"=>{"class"=>"RuntimeError", "message"=>"foo"})
    bt.must_be_kind_of Array
    bt.each{|line| line.must_be_kind_of String}
  end

  it "should handle backtrace lines in unexpected forms" do
    ep_app do |e|
      e.backtrace.first.upcase!
      e.backtrace[-1] = ''
      exception_page(e)
    end
    body = body('HTTP_ACCEPT'=>'text/html')
    body.must_include "RuntimeError: foo"
    body.must_include __FILE__
    body.must_include 'id="c0"'
  end

  it "should still show line numbers if the line content cannot be displayed" do
    app(:exception_page) do |r|
      instance_eval('raise "foo"', 'foo-bar.rb', 4200+42) rescue exception_page($!)
    end
    body = body('HTTP_ACCEPT'=>'text/html')
    body.must_include "RuntimeError: foo"
    body.must_include "foo-bar.rb:#{4200+42}"
    body.must_include __FILE__
    body.must_include 'id="c1"'
  end

  it "should serve exception page assets" do
    app(:exception_page) do |r|
      r.exception_page_assets
    end

    s, h, b = req('/exception_page.css')
    s.must_equal 200
    h['Content-Type'].must_equal 'text/css'
    b.join.must_equal Roda::RodaPlugins::ExceptionPage.css

    s, h, b = req('/exception_page.js')
    s.must_equal 200
    h['Content-Type'].must_equal 'application/javascript'
    b.join.must_equal Roda::RodaPlugins::ExceptionPage.js
  end
end
