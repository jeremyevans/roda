# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The exception_page plugin provides an exception_page method that is designed
    # to be called inside the error handler to provide a page to the developer
    # with debugging information. It should only be used in developer environments
    # with trusted clients, as it can leak source code and other information that
    # may be useful for attackers if used in other environments.
    #
    # Example:
    #
    #   plugin :exception_page
    #   plugin :error_handler do |e|
    #     next exception_page(e) if ENV['RACK_ENV'] == 'development'
    #     # ...
    #   end
    #
    # The exception_page plugin is based on Rack::ShowExceptions, with the following
    # differences:
    #
    # * Not a middleware, so it doesn't handle exceptions itself, and has no effect
    #   on the callstack unless the exception_page method is called.
    # * Supports external javascript and stylesheets, allowing context toggling to
    #   work in applications that use a content security policy to restrict inline
    #   javascript and stylesheets (:assets, :css_file, and :js_file options).
    # * Has fewer dependencies (does not require ostruct and erb).
    # * Sets the Content-Type for the response, and returns the body string, but does
    #   not modify other headers or the response status.
    # * Supports a configurable amount of context lines in backtraces (:context option).
    # * Supports optional JSON formatted output, if used with the json plugin (:json option).
    #
    # To use the external javascript and stylesheets, you can call +r.exception_page_assets+
    # in your routing tree:
    #
    #   route do |r|
    #     # ...
    #
    #     # serve GET /exception_page.{css,js} requests
    #     # Use with assets: true +exception_page+ option
    #     r.exception_page_assets
    #     
    #     r.on "static" do
    #       # serve GET /static/exception_page.{css,js} requests
    #       # Use with assets: '/static' +exception_page+ option
    #       r.exception_page_assets
    #     end
    #   end
    #
    # It's also possible to store the asset information in static files and serve those,
    # you can get the current assets by calling:
    #
    #   Roda::RodaPlugins::ExceptionPage.css
    #   Roda::RodaPlugins::ExceptionPage.js
    #
    # To customize the CSS or JS that applies to the exception page without creating
    # static files, you can use a callable to modify the defaults as they are passed
    # in:
    #
    #   plugin :exception_page,
    #     assets: ->(css, js) {
    #       css.concat("\n", 'html { background: "#facade" }')
    #       js.concat("\n", 'console.log("hello")')
    #
    #       [css, js]
    #     }
    #
    # As the exception_page plugin is based on Rack::ShowExceptions, it is also under
    # rack's license:
    #
    # Copyright (C) 2007-2018 Christian Neukirchen <http://chneukirchen.org/infopage.html>
    #
    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to
    # deal in the Software without restriction, including without limitation the
    # rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
    # sell copies of the Software, and to permit persons to whom the Software is
    # furnished to do so, subject to the following conditions:
    #
    # The above copyright notice and this permission notice shall be included in
    # all copies or substantial portions of the Software.
    #
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
    # THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
    # IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    # CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    #
    # The HTML template used in Rack::ShowExceptions was based on Django's
    # template and is under the following license:
    #
    # adapted from Django <www.djangoproject.com>
    # Copyright (c) Django Software Foundation and individual contributors.
    # Used under the modified BSD license:
    # http://www.xfree86.org/3.3.6/COPYRIGHT2.html#5
    module ExceptionPage
      def self.load_dependencies(app, opts=OPTS)
        app.plugin :h
      end

      # Use the CSS given as the :css option as the exception page's CSS and the
      # JavaScript given as the :js option as the exception page's JavaScript,
      # falling back to the defaults when not given.
      def self.configure(app, opts=OPTS)
        css, js = opts.fetch(:assets, NOOP).call(+self.css, +self.js)
        app.exception_page_css = -css
        app.exception_page_js = -js
      end

      # Default stylesheet used by the HTML exception page
      def self.css
        <<END
html * { padding:0; margin:0; }
body * { padding:10px 20px; }
body * * { padding:0; }
body { font:small sans-serif; }
body>div { border-bottom:1px solid #ddd; }
h1 { font-weight:normal; }
h2 { margin-bottom:.8em; }
h2 span { font-size:80%; color:#666; font-weight:normal; }
h3 { margin:1em 0 .5em 0; }
h4 { margin:0 0 .5em 0; font-weight: normal; }
table {
    border:1px solid #ccc; border-collapse: collapse; background:white; }
tbody td, tbody th { vertical-align:top; padding:2px 3px; }
thead th {
    padding:1px 6px 1px 3px; background:#fefefe; text-align:left;
    font-weight:normal; font-size:11px; border:1px solid #ddd; }
tbody th { text-align:right; color:#666; padding-right:.5em; }
table.vars { margin:5px 0 2px 40px; }
table.vars td, table.req td { font-family:monospace; }
table td.code { width:100%;}
table td.code div { overflow:hidden; }
table.source th { color:#666; }
table.source td {
    font-family:monospace; white-space:pre; border-bottom:1px solid #eee; }
ul.traceback { list-style-type:none; }
ul.traceback li.frame { margin-bottom:1em; }
div.context { margin: 10px 0; }
div.context ol {
    padding-left:30px; margin:0 10px; list-style-position: inside; }
div.context ol li {
    font-family:monospace; white-space:pre; color:#666; cursor:pointer; }
div.context ol.context-line li { color:black; background-color:#ccc; }
div.context ol.context-line li span { float: right; }
div.commands { margin-left: 40px; }
div.commands a { color:black; text-decoration:none; }
#summary { background: #ffc; }
#summary h2 { font-weight: normal; color: #666; font-family: monospace; white-space: pre-wrap;}
#summary ul#quicklinks { list-style-type: none; margin-bottom: 2em; }
#summary ul#quicklinks li { float: left; padding: 0 1em; }
#summary ul#quicklinks>li+li { border-left: 1px #666 solid; }
#explanation { background:#eee; }
#traceback { background:#eee; }
#requestinfo { background:#f6f6f6; padding-left:120px; }
#summary table { border:none; background:transparent; }
#requestinfo h2, #requestinfo h3 { position:relative; margin-left:-100px; }
#requestinfo h3 { margin-bottom:-1em; }
.error { background: #ffc; }
.specific { color:#cc3300; font-weight:bold; }
END
      end

      # Default Javascript used by the HTML exception page for context toggling
      def self.js
        <<END
var contexts = document.getElementsByClassName('context');
var num_contexts = contexts.length;
function toggle() {
  for (var i = 0; i < arguments.length; i++) {
    var e = document.getElementById(arguments[i]);
    if (e) {
      e.style.display = e.style.display == 'none' ? 'block' : 'none';
    }
  }
  return false;
}
for (var j = 0; j < num_contexts; j++) {
  contexts[j].onclick = function(){toggle('b'+this.id, 'a'+this.id);}
  contexts[j].onclick();
}
END
      end

      module ClassMethods
        # Read or set the CSS to render in the exception page's CSS file
        attr_accessor :exception_page_css

        # Read or set the Javascript to render in the exception page's JS file
        attr_accessor :exception_page_js
      end

      module InstanceMethods
        # Return a HTML page showing the exception, allowing a developer
        # more information for debugging.  Designed to be called inside
        # an exception handler, passing in the received exception.
        # Sets the Content-Type header in the response, and returns the
        # string used for the body.  If the Accept request header is present
        # and text/html is accepted, return an HTML page with the backtrace
        # with the ability to see the context for each backtrace line, as
        # well as the GET, POST, cookie, and rack environment data.  If text/html
        # is not accepted, then just show a plain text page with the exception
        # class, message, and backtrace.
        #
        # Options:
        # 
        # :assets :: If +true+, sets :css_file to +/exception_page.css+ and :js_file to
        #            +/exception_page.js+, assuming that +r.exception_page_assets+ is called
        #            in the route block to serve the exception page assets.  If a String,
        #            uses the string as a prefix, assuming that +r.exception_page_assets+
        #            is called in a nested block inside the route block. If false, doesn't
        #            use any CSS or JS.
        # :context :: The number of context lines before and after each line in
        #             the backtrace (default: 7).
        # :css_file :: A path to the external CSS file for the HTML exception page. If false,
        #              doesn't use any CSS.
        # :js_file :: A path to the external javascript file for the HTML exception page. If
        #             false, doesn't use any JS.
        # :json :: Return a hash of exception information.  The hash will have
        #          a single key, "exception", with a value being a hash with
        #          three keys, "class", "message", and "backtrace", which
        #          contain information derived from the given exception.
        #          Designed to be used with the +json+ exception, which will
        #          automatically convert the hash to JSON format.
        def exception_page(exception, opts=OPTS)
          message = exception_page_exception_message(exception)
          if opts[:json]
            @_response['Content-Type'] = "application/json"
            {
              "exception"=>{
                "class"=>exception.class.to_s,
                "message"=>message,
                "backtrace"=>exception.backtrace.map(&:to_s)
              }
            }
          elsif env['HTTP_ACCEPT'] =~ /text\/html/
            @_response['Content-Type'] = "text/html"

            context = opts[:context] || 7
            css_file = opts[:css_file]
            js_file = opts[:js_file]

            case prefix = opts[:assets]
            when false
              css_file = false if css_file.nil?
              js_file = false if js_file.nil?
            when nil
              # nothing
            else
              prefix = '' if prefix == true
              css_file ||= "#{prefix}/exception_page.css"
              js_file ||= "#{prefix}/exception_page.js"
            end

            css = case css_file
            when nil
              "<style type=\"text/css\">#{ExceptionPage.css}</style>"
            when false
              # :nothing
            else
              "<link rel=\"stylesheet\" href=\"#{h css_file}\" />"
            end

            js = case js_file
            when nil
              "<script type=\"text/javascript\">\n//<!--\n#{ExceptionPage.js}\n//-->\n</script>"
            when false
              # :nothing
            else
              "<script type=\"text/javascript\" src=\"#{h js_file}\"></script>"
            end

            frames = exception.backtrace.map.with_index do |line, i|
              frame = {:id=>i}
              if line =~ /\A(.*?):(\d+)(?::in `(.*)')?\Z/
                filename = frame[:filename] = $1
                lineno = frame[:lineno] = $2.to_i
                frame[:function] = $3

                begin
                  lineno -= 1
                  lines = ::File.readlines(filename)
                  if line = lines[lineno]
                    pre_lineno = [lineno-context, 0].max
                    if (pre_context = lines[pre_lineno...lineno]) && !pre_context.empty?
                      frame[:pre_context_lineno] = pre_lineno
                      frame[:pre_context] = pre_context
                    end

                    post_lineno = [lineno+context, lines.size].min
                    if (post_context = lines[lineno+1..post_lineno]) && !post_context.empty?
                      frame[:post_context_lineno] = post_lineno
                      frame[:post_context] = post_context
                    end

                    frame[:context_line] = line.chomp
                  end
                rescue
                end

                frame
              end
            end.compact

            r = @_request
            begin 
              post_data = r.POST
              missing_post = "No POST data"
            rescue
              missing_post = "Invalid POST data"
            end
            info = lambda do |title, id, var, none|
              <<END
  <h3 id="#{id}">#{title}</h3>
  #{(var && !var.empty?) ? (<<END1) : "<p>#{none}</p>"
    <table class="req">
      <thead>
        <tr>
          <th>Variable</th>
          <th>Value</th>
        </tr>
      </thead>
      <tbody>
          #{var.sort_by{|k, _| k.to_s}.map{|key, val| (<<END2)}.join
          <tr>
            <td>#{h key}</td>
            <td class="code"><div>#{h val.inspect}</div></td>
          </tr>
END2
}
      </tbody>
    </table>
END1
}
END
            end

            <<END
<!DOCTYPE html>
<html lang="en">
<head>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <title>#{h exception.class} at #{h r.path}</title>
  #{css}
</head>
<body>

<div id="summary">
  <h1>#{h exception.class} at #{h r.path}</h1>
  <h2>#{h message}</h2>
  <table><tr>
    <th>Ruby</th>
    <td>
#{(first = frames.first) ? "<code>#{h first[:filename]}</code>: in <code>#{h first[:function]}</code>, line #{first[:lineno]}" : "unknown location"}
    </td>
  </tr><tr>
    <th>Web</th>
    <td><code>#{r.request_method} #{h r.host}#{h r.path}</code></td>
  </tr></table>

  <h3>Jump to:</h3>
  <ul id="quicklinks">
    <li><a href="#get-info">GET</a></li>
    <li><a href="#post-info">POST</a></li>
    <li><a href="#cookie-info">Cookies</a></li>
    <li><a href="#env-info">ENV</a></li>
  </ul>
</div>

<div id="traceback">
  <h2>Traceback <span>(innermost first)</span></h2>
  <ul class="traceback">
#{frames.map{|frame| id = frame[:id]; (<<END1)}.join
      <li class="frame">
        <code>#{h frame[:filename]}:#{frame[:lineno]}</code> in <code>#{h frame[:function]}</code>

          #{frame[:context_line] ? (<<END2) : '</li>'
          <div class="context" id="c#{id}">
            #{frame[:pre_context] ? (<<END3) : ''
            <ol start="#{frame[:pre_context_lineno]+1}" id="bc#{id}">
              #{frame[:pre_context].map{|line| "<li>#{h line}</li>"}.join}
            </ol>
END3
}

            <ol start="#{frame[:lineno]}" class="context-line">
              <li>#{h frame[:context_line]}<span>...</span></li>
            </ol>

            #{frame[:post_context] ? (<<END4) : ''
            <ol start='#{frame[:lineno]+1}' id="ac#{id}">
              #{frame[:post_context].map{|line| "<li>#{h line}</li>"}.join}
            </ol>
END4
}
          </div>
END2
}
END1
}
  </ul>
</div>

<div id="requestinfo">
  <h2>Request information</h2>

  #{info.call('GET', 'get-info', r.GET, 'No GET data')}
  #{info.call('POST', 'post-info', post_data, missing_post)}
  #{info.call('Cookies', 'cookie-info', r.cookies, 'No cookie data')}
  #{info.call('Rack ENV', 'env-info', r.env, 'No Rack env?')}
</div>

<div id="explanation">
  <p>
    You're seeing this error because you use the Roda exception_page plugin.
  </p>
</div>

#{js}
</body>
</html>
END
          else
            @_response['Content-Type'] = "text/plain"
            "#{exception.class}: #{message}\n#{exception.backtrace.map{|l| "\t#{l}"}.join("\n")}"
          end
        end

        private

        if RUBY_VERSION >= '3.2'
          def exception_page_exception_message(exception)
            exception.detailed_message(highlight: false).to_s
          end
        # :nocov:
        else
          # Return message to use for exception.
          def exception_page_exception_message(exception)
            exception.message.to_s
          end
        end
        # :nocov:
      end

      module RequestMethods
        # Serve exception page assets
        def exception_page_assets
          get 'exception_page.css' do
            response['Content-Type'] = "text/css"
            roda_class.exception_page_css
          end
          get 'exception_page.js' do
            response['Content-Type'] = "application/javascript"
            roda_class.exception_page_js
          end
        end
      end
    end

    register_plugin(:exception_page, ExceptionPage)
  end
end
