# frozen-string-literal: true

require_relative '../roda'
require_relative 'plugins/sessions'

# Session middleware that can be used in any Rack application
# that uses Roda's sessions plugin for encrypted and signed cookies.
# See Roda::RodaPlugins::Sessions for details on options.
class RodaSessionMiddleware
  # Class to hold session data.  This is designed to mimic the API
  # of Rack::Session::Abstract::SessionHash, but is simpler and faster.
  # Undocumented methods operate the same as hash methods, but load the
  # session from the cookie if it hasn't been loaded yet, and convert
  # keys to strings.
  #
  # One difference between SessionHash and Rack::Session::Abstract::SessionHash
  # is that SessionHash does not attempt to setup a session id, since
  # one is not needed for cookie-based sessions, only for sessions
  # that are loaded out of a database.  If you need to have a session id
  # for other reasons, manually create a session id using a randomly generated
  # string.
  class SessionHash
    # The Roda::RodaRequest subclass instance related to the session.
    attr_reader :req

    # The underlying data hash, or nil if the session has not yet been
    # loaded.
    attr_reader :data

    def initialize(req)
      @req = req
      @data = nil
    end

    # The Roda sessions plugin options used by the middleware for this
    # session hash.
    def options
      @req.roda_class.opts[:sessions]
    end

    def each(&block)
      load!
      @data.each(&block)
    end

    def [](key)
      load!
      @data[key.to_s]
    end

    def fetch(key, default = (no_default = true), &block)
      load!
      if no_default
        @data.fetch(key.to_s, &block)
      else
        @data.fetch(key.to_s, default, &block)
      end
    end

    def has_key?(key)
      load!
      @data.has_key?(key.to_s)
    end
    alias :key? :has_key?
    alias :include? :has_key?

    def []=(key, value)
      load!
      @data[key.to_s] = value
    end
    alias :store :[]=

    # Clear the session, also removing a couple of roda session
    # keys from the environment so that the related cookie will
    # either be set or cleared in the rack response.
    def clear
      load!
      env = @req.env
      env.delete('roda.session.created_at')
      env.delete('roda.session.updated_at')
      @data.clear
    end
    alias :destroy :clear

    def to_hash
      load!
      @data.dup
    end

    def update(hash)
      load!
      hash.each do |key, value|
        @data[key.to_s] = value
      end
      @data
    end
    alias :merge! :update

    def replace(hash)
      load!
      @data.clear
      update(hash)
    end

    def delete(key)
      load!
      @data.delete(key.to_s)
    end

    # If the session hasn't been loaded, display that.
    def inspect
      if loaded?
        @data.inspect
      else
        "#<#{self.class}:0x#{self.object_id.to_s(16)} not yet loaded>"
      end
    end

    # Return whether the session cookie already exists.
    # If this is false, then the session was set to an empty hash.
    def exists?
      load!
      req.env.has_key?('roda.session.serialized')
    end

    # Whether the session has already been loaded from the cookie yet.
    def loaded?
      !!@data
    end

    def empty?
      load!
      @data.empty?
    end

    def keys
      load!
      @data.keys
    end

    def values
      load!
      @data.values
    end

    private

    # Load the session from the cookie.
    def load!
      @data ||= @req.send(:_load_session)
    end
  end

  module RequestMethods
    # Work around for if type_routing plugin is loaded into Roda class itself.
    def _remaining_path(_)
    end
  end

  # Setup the middleware, passing +opts+ as the Roda sessions plugin options.
  def initialize(app, opts)
    mid = Class.new(Roda)
    Roda::RodaPlugins.set_temp_name(mid){"RodaSessionMiddleware::_RodaSubclass"}
    mid.plugin :sessions, opts
    @req_class = mid::RodaRequest
    @req_class.send(:include, RequestMethods)
    @app = app
  end

  # Initialize the session hash in the environment before calling the next
  # application, and if the session has been loaded after the result has been
  # returned, then persist the session in the cookie.
  def call(env)
    session = env['rack.session'] = SessionHash.new(@req_class.new(nil, env))

    res = @app.call(env)

    if session.loaded?
      session.req.persist_session(res[1], session.data)
    end

    res
  end
end
