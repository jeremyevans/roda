$:.unshift(File.expand_path("../lib", File.dirname(__FILE__)))

if RUBY_VERSION >= '3'
  begin
    require 'warning'
  rescue LoadError
  else
    Warning.ignore(%r{gems/(mail|minjs)-\d})
    Warning.dedup if Warning.respond_to?(:dedup)
  end
end

if rack_gem_version = ENV.delete('COVERAGE')
  gem 'rack', rack_gem_version
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    command_name "rack #{rack_gem_version}"
    add_filter{|f| f.filename.match(%r{\A#{Regexp.escape(File.dirname(__FILE__))}/})}
    add_group('Missing'){|src| src.covered_percent < 100}
    add_group('Covered'){|src| src.covered_percent == 100}
  end
end

require 'rack/lint' if ENV['LINT']
require_relative "../lib/roda"
require "stringio"

ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
gem 'minitest'
require "minitest/global_expectations/autorun"
require 'minitest/hooks/default'

if ENV['CHECK_METHOD_VISIBILITY']
  require 'visibility_checker'
  VISIBILITY_CHANGES = []
  Minitest.after_run do
    if VISIBILITY_CHANGES.empty?
      puts "No visibility changes"
    else
      puts "Visibility changes:"
      VISIBILITY_CHANGES.uniq!{|v,| v}
      puts(*VISIBILITY_CHANGES.map do |v, caller|
        "#{caller}: #{v.new_visibility} method #{v.overridden_by}##{v.method} overrides #{v.original_visibility} method in #{v.defined_in}"
      end.sort)
    end
  end
end

if ENV['PLAIN_HASH_RESPONSE_HEADERS']
  Roda.plugin :plain_hash_response_headers
end

if ENV['SHAPE_FRIENDLY']
  Roda.plugin :shape_friendly
end

RodaResponseHeaders = Roda::RodaResponseHeaders

$RODA_WARN = true
def (Roda::RodaPlugins).warn(s)
  return unless $RODA_WARN
  $stderr.puts s
  puts caller.grep(/_spec\.rb:\d+:/)
end

if ENV['RODA_RACK_SESSION_COOKIE'] != '1'
  require_relative '../lib/roda/session_middleware'
  DEFAULT_SESSION_MIDDLEWARE_ARGS =  [RodaSessionMiddleware, :secret=>'1'*64]
  DEFAULT_SESSION_ARGS = [:plugin, :sessions, :secret=>'1'*64]
else
  DEFAULT_SESSION_MIDDLEWARE_ARGS = [Rack::Session::Cookie, :secret=>'1']
  DEFAULT_SESSION_ARGS = [:use, Rack::Session::Cookie, :secret=>'1']
end

if defined?(Rack::Headers)
  class Rack::Headers
    def must_equal(hash)
      case hash
      when Hash
        must_be(:==, Rack::Headers[hash])
      else
        super
      end
    end
  end

  class Array
    def must_equal(array)
      case array
      when Array
        if array.length == 3 && array[1].is_a?(Hash)
          must_be(:==, [array[0], Rack::Headers[array[1]], array[2]])
        else
          super
        end
      else
        super
      end
    end
  end
end

require 'uri' if ENV['LINT']

module CookieJar
  def req(path='/', env={})
    if path.is_a?(Hash)
      env = path
    else
      env['PATH_INFO'] = path.dup
    end
    env['HTTP_COOKIE'] = @cookie if @cookie

    a = super(env)
    if (set = a[1][RodaResponseHeaders::SET_COOKIE]).is_a?(String)
      # This currently doesn't handle setting multiple cookies in the same response.
      # Support for that isn't yet needed in the specs.
      @cookie = set.sub(/(; path=\/)?(; secure)?; HttpOnly/, '')
    end
    a
  end
end

class Minitest::Spec
  def self.deprecated(a, &block)
    it("#{a} (deprecated)") do
      begin
        $RODA_WARN = false
        instance_exec(&block)
      ensure
        $RODA_WARN = true
      end
    end
  end

  def rack_input(str='')
    StringIO.new(str.dup.force_encoding('BINARY'))
  end

  def app(type=nil, &block)
    case type
    when :new
      @app = _app{route(&block) if block}
    when :bare
      @app = _app(&block)
    when Symbol
      @app = _app do
        plugin type
        route(&block)
      end
    else
      if block
        @app = _app{route(&block)}
      else
        @app ||= _app{}
      end
    end
    if ENV['CHECK_METHOD_VISIBILITY']
      caller = caller_locations(1, 1)[0]
      [@app, @app::RodaRequest, @app::RodaResponse].each do |c|
        VISIBILITY_CHANGES.concat(VisibilityChecker.visibility_changes(c).map{|v| [v, "#{caller.path}:#{caller.lineno}"]})
      end
    end
    @app
  end

  def req(path='/', env={})
    if path.is_a?(Hash)
      env = path
    else
      env['PATH_INFO'] = path.dup
    end

    _req(@app, env)
  end

  def req_env(env)
    env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/", "SCRIPT_NAME" => ""}.merge!(env)
    if ENV['LINT']
      env['SERVER_NAME'] ||= 'example.com'
      env['SERVER_PROTOCOL'] ||= env['HTTP_VERSION'] || 'HTTP/1.0'
      env['HTTP_VERSION'] ||= env['SERVER_PROTOCOL']
      env['QUERY_STRING'] ||= ''
      env['rack.input'] ||= rack_input
      env['rack.errors'] ||= StringIO.new
      env['rack.url_scheme'] ||= 'http'

      env['rack.version'] = [1, 5]
      if Rack.release < '2.3'
        env['SERVER_PORT'] ||= '80'
        env['rack.multiprocess'] = env['rack.multithread'] = env['rack.run_once'] = false
      end
    end
    env
  end

  def _req(app, env)
    a = @app.call(req_env(env))

    if ENV['LINT']
      orig = a[2]
      a[2] = a[2].to_enum(:each).to_a
      orig.close if orig.respond_to?(:close)
      a[2].define_singleton_method(:to_path){orig.to_path} if orig.respond_to?(:to_path)
    end

    a
  end

  def unless_lint
    yield unless ENV['LINT']
  end

  def status(path='/', env={})
    req(path, env)[0]
  end

  def header(name, path='/', env={})
    req(path, env)[1][name]
  end

  def body(path='/', env={})
    s = String.new
    b = req(path, env)[2]
    b.each{|x| s << x}
    b.close if b.respond_to?(:close)
    s
  end

  def _app(&block)
    c = Class.new(Roda)
    c.use Rack::Lint if ENV['LINT']
    c.class_eval(&block)
    c
  end

  def with_rack_env(env)
    ENV['RACK_ENV'] = env
    yield
  ensure
    ENV.delete('RACK_ENV')
  end
end
