# frozen-string-literal: true

begin
  require "rack/version"
rescue LoadError
  require "rack"
else
  if Rack.release >= '3'
    require "rack/request"
  else
    require "rack"
  end
end

require 'set'
require_relative "cache"

class Roda
  # Base class used for Roda requests.  The instance methods for this
  # class are added by Roda::RodaPlugins::Base::RequestMethods, the
  # class methods are added by Roda::RodaPlugins::Base::RequestClassMethods.
  class RodaRequest < ::Rack::Request
    @roda_class = ::Roda
    @match_pattern_cache = ::Roda::RodaCache.new
  end

  module RodaPlugins
    module Base
      # Class methods for RodaRequest
      module RequestClassMethods
        # Reference to the Roda class related to this request class.
        attr_accessor :roda_class

        # The cache to use for match patterns for this request class.
        attr_accessor :match_pattern_cache

        # Return the cached pattern for the given object.  If the object is
        # not already cached, yield to get the basic pattern, and convert the
        # basic pattern to a pattern that does not match partial segments.
        def cached_matcher(obj)
          cache = @match_pattern_cache

          unless pattern = cache[obj]
            pattern = cache[obj] = consume_pattern(yield)
          end

          pattern
        end

        # Since RodaRequest is anonymously subclassed when Roda is subclassed,
        # and then assigned to a constant of the Roda subclass, make inspect
        # reflect the likely name for the class.
        def inspect
          "#{roda_class.inspect}::RodaRequest"
        end

        private

        # The pattern to use for consuming, based on the given argument.  The returned
        # pattern requires the path starts with a string and does not match partial
        # segments.
        def consume_pattern(pattern)
          /\A\/(?:#{pattern})(?=\/|\z)/
        end
      end

      # Instance methods for RodaRequest, mostly related to handling routing
      # for the request.
      module RequestMethods
        TERM = Object.new
        def TERM.inspect
          "TERM"
        end
        TERM.freeze

        # The current captures for the request.  This gets modified as routing
        # occurs.
        attr_reader :captures

        # The Roda instance related to this request object.  Useful if routing
        # methods need access to the scope of the Roda route block.
        attr_reader :scope

        # Store the roda instance and environment.
        def initialize(scope, env)
          @scope = scope
          @captures = []
          @remaining_path = _remaining_path(env)
          @env = env
        end

        # Handle match block return values.  By default, if a string is given
        # and the response is empty, use the string as the response body.
        def block_result(result)
          res = response
          if res.empty? && (body = block_result_body(result))
            res.write(body)
          end
        end

        # Match GET requests.  If no arguments are provided, matches all GET
        # requests, otherwise, matches only GET requests where the arguments
        # given fully consume the path.
        def get(*args, &block)
          _verb(args, &block) if is_get?
        end

        # Immediately stop execution of the route block and return the given
        # rack response array of status, headers, and body.  If no argument
        # is given, uses the current response.
        #
        #   r.halt [200, {'Content-Type'=>'text/html'}, ['Hello World!']]
        #   
        #   response.status = 200
        #   response['Content-Type'] = 'text/html'
        #   response.write 'Hello World!'
        #   r.halt
        def halt(res=response.finish)
          throw :halt, res
        end

        # Show information about current request, including request class,
        # request method and full path.
        #
        #   r.inspect
        #   # => '#<Roda::RodaRequest GET /foo/bar>'
        def inspect
          "#<#{self.class.inspect} #{@env["REQUEST_METHOD"]} #{path}>"
        end

        if Rack.release >= '3'
          def http_version
            # Prefer SERVER_PROTOCOL as it is required in Rack 3.
            # Still fall back to HTTP_VERSION if SERVER_PROTOCOL
            # is not set, in case the server in use is not Rack 3
            # compliant.
            @env['SERVER_PROTOCOL'] || @env['HTTP_VERSION']
          end
        else
          # What HTTP version the request was submitted with.
          def http_version
            # Prefer HTTP_VERSION as it is backwards compatible
            # with previous Roda versions. Fallback to
            # SERVER_PROTOCOL for servers that do not set
            # HTTP_VERSION.
            @env['HTTP_VERSION'] || @env['SERVER_PROTOCOL']
          end
        end

        # Does a terminal match on the current path, matching only if the arguments
        # have fully matched the path.  If it matches, the match block is
        # executed, and when the match block returns, the rack response is
        # returned.
        # 
        #   r.remaining_path
        #   # => "/foo/bar"
        #
        #   r.is 'foo' do
        #     # does not match, as path isn't fully matched (/bar remaining)
        #   end
        #
        #   r.is 'foo/bar' do
        #     # matches as path is empty after matching
        #   end
        #
        # If no arguments are given, matches if the path is already fully matched.
        # 
        #   r.on 'foo/bar' do
        #     r.is do
        #       # matches as path is already empty
        #     end
        #   end
        #
        # Note that this matches only if the path after matching the arguments
        # is empty, not if it still contains a trailing slash:
        #
        #   r.remaining_path
        #   # =>  "/foo/bar/"
        #
        #   r.is 'foo/bar' do
        #     # does not match, as path isn't fully matched (/ remaining)
        #   end
        # 
        #   r.is 'foo/bar/' do
        #     # matches as path is empty after matching
        #   end
        # 
        #   r.on 'foo/bar' do
        #     r.is "" do
        #       # matches as path is empty after matching
        #     end
        #   end
        def is(*args, &block)
          if args.empty?
            if empty_path?
              always(&block)
            end
          else
            args << TERM
            if_match(args, &block)
          end
        end

        # Optimized method for whether this request is a +GET+ request.
        # Similar to the default Rack::Request get? method, but can be
        # overridden without changing rack's behavior.
        def is_get?
          @env["REQUEST_METHOD"] == 'GET'
        end

        # Does a match on the path, matching only if the arguments
        # have matched the path.  Because this doesn't fully match the
        # path, this is usually used to setup branches of the routing tree,
        # not for final handling of the request.
        # 
        #   r.remaining_path
        #   # => "/foo/bar"
        #
        #   r.on 'foo' do
        #     # matches, path is /bar after matching
        #   end
        #
        #   r.on 'bar' do
        #     # does not match
        #   end
        #
        # Like other routing methods, If it matches, the match block is
        # executed, and when the match block returns, the rack response is
        # returned.  However, in general you will call another routing method
        # inside the match block that fully matches the path and does the
        # final handling for the request:
        #
        #   r.on 'foo' do
        #     r.is 'bar' do
        #       # handle /foo/bar request
        #     end
        #   end
        def on(*args, &block)
          if args.empty?
            always(&block)
          else
            if_match(args, &block)
          end
        end

        # The already matched part of the path, including the original SCRIPT_NAME.
        def matched_path
          e = @env
          e["SCRIPT_NAME"] + e["PATH_INFO"].chomp(@remaining_path)
        end

        # This an an optimized version of Rack::Request#path.
        #
        #   r.env['SCRIPT_NAME'] = '/foo'
        #   r.env['PATH_INFO'] = '/bar'
        #   r.path
        #   # => '/foo/bar'
        def path
          e = @env
          "#{e["SCRIPT_NAME"]}#{e["PATH_INFO"]}"
        end

        # The current path to match requests against.
        attr_reader :remaining_path

        # An alias of remaining_path. If a plugin changes remaining_path then
        # it should override this method to return the untouched original.
        alias real_remaining_path remaining_path

        # Match POST requests.  If no arguments are provided, matches all POST
        # requests, otherwise, matches only POST requests where the arguments
        # given fully consume the path.
        def post(*args, &block)
          _verb(args, &block) if post?
        end

        # Immediately redirect to the path using the status code.  This ends
        # the processing of the request:
        #
        #   r.redirect '/page1', 301 if r['param'] == 'value1'
        #   r.redirect '/page2' # uses 302 status code
        #   response.status = 404 # not reached
        #   
        # If you do not provide a path, by default it will redirect to the same
        # path if the request is not a +GET+ request.  This is designed to make
        # it easy to use where a +POST+ request to a URL changes state, +GET+
        # returns the current state, and you want to show the current state
        # after changing:
        #
        #   r.is "foo" do
        #     r.get do
        #       # show state
        #     end
        #   
        #     r.post do
        #       # change state
        #       r.redirect
        #     end
        #   end
        def redirect(path=default_redirect_path, status=default_redirect_status)
          response.redirect(path, status)
          throw :halt, response.finish
        end

        # The response related to the current request.  See ResponseMethods for
        # instance methods for the response, but in general the most common usage
        # is to override the response status and headers:
        #
        #   response.status = 200
        #   response['Header-Name'] = 'Header value'
        def response
          @scope.response
        end

        # Return the Roda class related to this request.
        def roda_class
          self.class.roda_class
        end

        # Match method that only matches +GET+ requests where the current
        # path is +/+.  If it matches, the match block is executed, and when
        # the match block returns, the rack response is returned.
        #
        #   [r.request_method, r.remaining_path]
        #   # => ['GET', '/']
        #
        #   r.root do
        #     # matches
        #   end
        #
        # This is usuable inside other match blocks:
        #
        #   [r.request_method, r.remaining_path]
        #   # => ['GET', '/foo/']
        #
        #   r.on 'foo' do
        #     r.root do
        #       # matches
        #     end
        #   end
        #
        # Note that this does not match non-+GET+ requests:
        #
        #   [r.request_method, r.remaining_path]
        #   # => ['POST', '/']
        #
        #   r.root do
        #     # does not match
        #   end
        #
        # Use <tt>r.post ""</tt> for +POST+ requests where the current path
        # is +/+.
        # 
        # Nor does it match empty paths:
        #
        #   [r.request_method, r.remaining_path]
        #   # => ['GET', '/foo']
        #
        #   r.on 'foo' do
        #     r.root do
        #       # does not match
        #     end
        #   end
        #
        # Use <tt>r.get true</tt> to handle +GET+ requests where the current
        # path is empty.
        def root(&block)
          if @remaining_path == "/" && is_get?
            always(&block)
          end
        end

        # Call the given rack app with the environment and return the response
        # from the rack app as the response for this request.  This ends
        # the processing of the request:
        #
        #   r.run(proc{[403, {}, []]}) unless r['letmein'] == '1'
        #   r.run(proc{[404, {}, []]})
        #   response.status = 404 # not reached
        #
        # This updates SCRIPT_NAME/PATH_INFO based on the current remaining_path
        # before dispatching to another rack app, so the app still works as
        # a URL mapper.
        def run(app)
          e = @env
          path = real_remaining_path
          sn = "SCRIPT_NAME"
          pi = "PATH_INFO"
          script_name = e[sn]
          path_info = e[pi]
          begin
            e[sn] += path_info.chomp(path)
            e[pi] = path
            throw :halt, app.call(e)
          ensure
            e[sn] = script_name
            e[pi] = path_info
          end
        end

        # The session for the current request.  Raises a RodaError if
        # a session handler has not been loaded.
        def session
          @env['rack.session'] || raise(RodaError, "You're missing a session handler, try using the sessions plugin.")
        end

        private

        # Match any of the elements in the given array.  Return at the
        # first match without evaluating future matches.  Returns false
        # if no elements in the array match.
        def _match_array(matcher)
          matcher.any? do |m|
            if matched = match(m)
              if m.is_a?(String)
                @captures.push(m)
              end
            end

            matched
          end
        end

        # Match the given class.  Currently, the following classes
        # are supported by default:
        # Integer :: Match an integer segment, yielding result to block as an integer
        # String :: Match any non-empty segment, yielding result to block as a string
        def _match_class(klass)
          meth = :"_match_class_#{klass}"
          if respond_to?(meth, true)
            # Allow calling private methods, as match methods are generally private
            send(meth)
          else
            unsupported_matcher(klass)
          end
        end

        # Match the given hash if all hash matchers match.
        def _match_hash(hash)
          # Allow calling private methods, as match methods are generally private
          hash.all?{|k,v| send("match_#{k}", v)}
        end

        # Match integer segment of up to 100 decimal characters, and yield resulting value as an
        # integer.
        def _match_class_Integer
          consume(/\A\/(\d{1,100})(?=\/|\z)/, :_convert_class_Integer)
        end

        # Match only if all of the arguments in the given array match.
        # Match the given regexp exactly if it matches a full segment.
        def _match_regexp(re)
          consume(self.class.cached_matcher(re){re})
        end

        # Match the given string to the request path.  Matches only if the
        # request path ends with the string or if the next character in the
        # request path is a slash (indicating a new segment).
        def _match_string(str)
          rp = @remaining_path
          length = str.length

          match = case rp.rindex(str, length)
          when nil
            # segment does not match, most common case
            return
          when 1
            # segment matches, check first character is /
            rp.getbyte(0) == 47
          else # must be 0
            # segment matches at first character, only a match if
            # empty string given and first character is /
            length == 0 && rp.getbyte(0) == 47
          end

          if match 
            length += 1
            case rp.getbyte(length)
            when 47
              # next character is /, update remaining path to rest of string
              @remaining_path = rp[length, 100000000]
            when nil
              # end of string, so remaining path is empty
              @remaining_path = ""
            # else
              # Any other value means this was partial segment match,
              # so we return nil in that case without updating the
              # remaining_path.  No need for explicit else clause.
            end
          end
        end

        # Match only if the next segment in the path is one of the
        # set's elements, and yield the next segment.
        def _match_set(set)
          rp = @remaining_path
          if key = _match_class_String
            if set.include?(@captures[-1])
              true
            else
              @remaining_path = rp
              @captures.pop
              false
            end
          end
        end

        # Match the given symbol if any segment matches.
        def _match_symbol(sym=nil)
          rp = @remaining_path
          if rp.getbyte(0) == 47
            if last = rp.index('/', 1)
              @captures << rp[1, last-1]
              @remaining_path = rp[last, rp.length]
            elsif (len = rp.length) > 1
              @captures << rp[1, len]
              @remaining_path = ""
            end
          end
        end

        # Match any nonempty segment.  This should be called without an argument.
        alias _match_class_String _match_symbol

        # The base remaining path to use.
        def _remaining_path(env)
          env["PATH_INFO"]
        end

        # Backbone of the verb method support, using a terminal match if
        # args is not empty, or a regular match if it is empty.
        def _verb(args, &block)
          if args.empty?
            always(&block)
          else
            args << TERM
            if_match(args, &block)
          end
        end

        # Yield to the match block and return rack response after the block returns.
        def always
          block_result(yield)
          throw :halt, response.finish
        end

        # The body to use for the response if the response does not already have
        # a body.  By default, a String is returned directly, and nil is
        # returned otherwise.
        def block_result_body(result)
          case result
          when String
            result
          when nil, false
            # nothing
          else
            unsupported_block_result(result)
          end
        end

        # Attempts to match the pattern to the current path.  If there is no
        # match, returns false without changes.  Otherwise, modifies
        # SCRIPT_NAME to include the matched path, removes the matched
        # path from PATH_INFO, and updates captures with any regex captures.
        def consume(pattern, meth=nil)
          if matchdata = pattern.match(@remaining_path)
            captures = matchdata.captures

            if meth
              return unless captures = scope.send(meth, *captures)
            # :nocov:
            elsif defined?(yield)
              # RODA4: Remove
              return unless captures = yield(*captures)
            # :nocov:
            end

            @remaining_path = matchdata.post_match

            if captures.is_a?(Array)
              @captures.concat(captures)
            else
              @captures << captures
            end
          end
        end

        # The default path to use for redirects when a path is not given.
        # For non-GET requests, redirects to the current path, which will
        # trigger a GET request.  This is to make the common case where
        # a POST request will redirect to a GET request at the same location
        # will work fine.
        #
        # If the current request is a GET request, raise an error, as otherwise
        # it is easy to create an infinite redirect.
        def default_redirect_path
          raise RodaError, "must provide path argument to redirect for get requests" if is_get?
          path
        end

        # The default status to use for redirects if a status is not provided,
        # 302 by default.
        def default_redirect_status
          302
        end

        # Whether the current path is considered empty.
        def empty_path?
          @remaining_path.empty?
        end

        # If all of the arguments match, yields to the match block and
        # returns the rack response when the block returns.  If any of
        # the match arguments doesn't match, does nothing.
        def if_match(args)
          path = @remaining_path
          # For every block, we make sure to reset captures so that
          # nesting matchers won't mess with each other's captures.
          captures = @captures.clear

          if match_all(args)
            block_result(yield(*captures))
            throw :halt, response.finish
          else
            @remaining_path = path
            false
          end
        end

        # Attempt to match the argument to the given request, handling
        # common ruby types.
        def match(matcher)
          case matcher
          when String
            _match_string(matcher)
          when Class
            _match_class(matcher)
          when TERM
            empty_path?
          when Regexp
            _match_regexp(matcher)
          when true
            matcher
          when Array
            _match_array(matcher)
          when Hash
            _match_hash(matcher)
          when Set
            _match_set(matcher)
          when Symbol
            _match_symbol(matcher)
          when false, nil
            matcher
          when Proc
            matcher.call
          else
            unsupported_matcher(matcher)
          end
        end

        # Match only if all of the arguments in the given array match.
        def match_all(args)
          args.all?{|arg| match(arg)}
        end

        # Match by request method.  This can be an array if you want
        # to match on multiple methods.
        def match_method(type)
          if type.is_a?(Array)
            type.any?{|t| match_method(t)}
          else
            type.to_s.upcase == @env["REQUEST_METHOD"]
          end
        end

        # How to handle block results that are not nil, false, or a String.
        # By default raises an exception.
        def unsupported_block_result(result)
          raise RodaError, "unsupported block result: #{result.inspect}"
        end

        # Handle an unsupported matcher.
        def unsupported_matcher(matcher)
          raise RodaError, "unsupported matcher: #{matcher.inspect}"
        end
      end
    end
  end
end
