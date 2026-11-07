# frozen-string-literal: true

require 'openssl'

begin
  OpenSSL::Cipher.new("aes-256-ctr")
rescue OpenSSL::Cipher::CipherError
  # simplecov:disable
  raise LoadError, "Roda sessions plugin requires the aes-256-ctr cipher"
  # simplecov:enable
end

require 'securerandom'
require 'zlib'
require 'rack/utils'

class Roda
  module RodaPlugins
    # The sessions plugin adds support for sessions using cookies. It is the recommended
    # way to support sessions in Roda applications.
    #
    # The session cookies are encrypted with AES-256-CTR using a separate encryption key per cookie,
    # and then signed with HMAC-SHA-256.  By default, session data is padded to reduce information
    # leaked based on the session size.
    #
    # Sessions are serialized via JSON, so session information should only store data that
    # allows roundtrips via JSON (String, Integer, Float, Array, Hash, true, false, and nil).
    # In particular, note that Symbol does not round trip via JSON, so symbols should not be
    # used in sessions when this plugin is used.  This plugin sets the
    # +:sessions_convert_symbols+ application option to +true+ if it hasn't been set yet,
    # for better integration with plugins that can use either symbol or string session or 
    # flash keys.  Unlike some other session implementations, the session is stored as a plain ruby hash,
    # and does not convert keys to strings.
    #
    # All sessions are timestamped and session expiration is enabled by default, with sessions
    # being valid for 30 days maximum and 7 days since last use by default.  Session creation time is
    # reset whenever the session is empty when serialized and also whenever +clear_session+
    # is called while processing the request.
    #
    # Session secrets can be rotated.  See options below.
    #
    # If the final cookie is too large (>=4096 bytes), a Roda::RodaPlugins::Sessions::CookieTooLarge
    # exception will be raised.
    #
    # = Required Keyword Arguments
    #
    # The session cookies this plugin uses are both encrypted and signed, so two separate
    # secrets are used internally.  However, for ease of use, these secrets are combined into
    # a single +secret+ argument.  The +secret+ argument must be a string of at least 64 bytes
    # and should be randomly generated.  The first 32 bytes are used as the secret for the
    # cipher, any remaining bytes are used for the secret for the HMAC.
    #
    # = Optional Keyword Arguments
    #
    # +cookie_options+ :: Any cookie options to set on the session cookie. By default, uses
    #                     <tt>httponly: true, path: '/', same_site: :lax</tt> so that the cookie is not accessible
    #                     to javascript, allowed for all paths, and will not be used for cross-site non-GET requests.
    #                     If the +:secure+ option is not present in the hash, then
    #                     <tt>secure: true</tt> is also set if the request is made over HTTPS.  If this option is
    #                     given, it will be merged into the default cookie options.
    # +env_key+ :: The key in `env` where the session should be located. Defaults to <tt>"rack.session"</tt>, the
    #              default key for sessions in Rack.
    # +key+ :: The cookie name to use (default: <tt>'roda.session'</tt>)
    # +max_idle_seconds+ :: The maximum number of seconds to allow since the session was last updated.
    #                       Default is <tt>86400*7</tt> (7 days).  Can be set to nil to disable session idleness
    #                       checks.
    # +max_seconds+ :: The maximum number of seconds to allow for total session lifetime, starting with when
    #                  the session was originally created.  Default is <tt>86400*30</tt> (30 days). Can be set to
    #                  +nil+ to disable session lifetime checks.
    # +old_secret+ :: The previous secret to use, allowing for secret rotation.  Must be a string of at least 64
    #                 bytes if given.
    # +pad_size+ :: Pad session data to a multiple of this many bytes (default: 32).  This can be between
    #               2-4096 bytes, or +nil+ to disable padding.
    # +parser+ :: The parser for the serialized session data (default: <tt>JSON.method(:parse)</tt>).
    # :serializer :: The serializer for the session data (default +:to_json.to_proc+).
    # :skip_within :: If the last update time for the session cookie is less than this number of seconds from the
    #                 current time, and the session has not been modified, do not set a new session cookie
    #                 (default: 3600).
    #
    # = Not a Rack Middleware
    # 
    # Unlike some other approaches to sessions, the sessions plugin does not use
    # a rack middleware, so session information is not available to other rack middleware,
    # only to the application itself, with the session not being loaded from the cookie
    # until the +session+ method is called.
    #
    # If you need rack middleware to access the session information, then
    # <tt>require 'roda/session_middleware'</tt> and <tt>use RodaSessionMiddleware</tt>.
    # <tt>RodaSessionMiddleware</tt> passes the options given to this plugin.
    #
    # = Session Cookie Cryptography/Format
    #
    # Session cookies created by this plugin by default use the following format:
    #
    #   urlsafe_base64("\1" + random_data + IV + encrypted session data + HMAC)
    #
    # where:
    #
    # version :: 1 byte, currently must be 1, other values reserved for future expansion.
    # random_data :: 32 bytes, used for generating the per-cookie secret
    # IV :: 16 bytes, initialization vector for AES-256-CTR cipher.
    # encrypted session data :: >=12 bytes of data encrypted with AES-256-CTR cipher, see below.
    # HMAC :: 32 bytes, HMAC-SHA-256 of all preceding data plus cookie key (so that a cookie value
    #         for a different key cannot be used even if the secret is the same).
    #  
    # The encrypted session data uses the following format:
    #
    #   bitmap + creation time + update time + padding + serialized data
    #
    # where:
    # 
    # bitmap :: 2 bytes in little endian format, lower 12 bits storing number of padding
    #           bytes.  Bits 13-16 reserved for future expansion.
    # creation time :: 4 byte integer in unsigned little endian format, storing unix timestamp
    #                  since session initially created.
    # update time :: 4 byte integer in unsigned little endian format, storing unix timestamp
    #                since session last updated.
    # padding :: >=0 padding bytes specified in bitmap, filled with random data, can be ignored.
    # serialized data :: >=2 bytes of serialized data in JSON format.
    module Sessions
      DEFAULT_COOKIE_OPTIONS = {:httponly=>true, :path=>'/'.freeze, :same_site=>:lax}.freeze
      DEFAULT_OPTIONS = {:key => 'roda.session'.freeze, :max_seconds=>86400*30, :max_idle_seconds=>86400*7, :pad_size=>32, :gzip_over=>nil, :skip_within=>3600, :env_key=>'rack.session'}.freeze
      DEFLATE_BIT  = 0x1000
      PADDING_MASK = 0x0fff
      SESSION_CREATED_AT = 'roda.session.created_at'.freeze
      SESSION_UPDATED_AT = 'roda.session.updated_at'.freeze
      SESSION_SERIALIZED = 'roda.session.serialized'.freeze
      SESSION_VERSION_NUM = 'roda.session.version'.freeze
      SESSION_DELETE_RACK_COOKIE = 'roda.session.delete_rack_session_cookie'.freeze

      %i[
        DEFAULT_COOKIE_OPTIONS
        DEFAULT_OPTIONS
        DEFLATE_BIT
        PADDING_MASK
        SESSION_CREATED_AT
        SESSION_UPDATED_AT
        SESSION_SERIALIZED
        SESSION_VERSION_NUM
        SESSION_DELETE_RACK_COOKIE].each do |sym|
          RodaPlugins.deprecate_constant self, sym
        end

      PLUGIN_ARGUMENTS = %i[
        cookie_options
        env_key
        gzip_over
        key
        max_idle_seconds
        max_seconds
        old_secret
        pad_size
        parser
        per_cookie_cipher_secret
        serializer
        secret
        skip_within
        upgrade_from_rack_session_cookie_key
        upgrade_from_rack_session_cookie_secret
        upgrade_from_rack_session_cookie_options
      ].freeze
      private_constant :PLUGIN_ARGUMENTS

      deprecated_plugin_arguments = %i[
        gzip_over
        per_cookie_cipher_secret
        upgrade_from_rack_session_cookie_key
        upgrade_from_rack_session_cookie_secret
        upgrade_from_rack_session_cookie_options
      ]

      Config = Struct.new(*(PLUGIN_ARGUMENTS - deprecated_plugin_arguments - %i[secret old_secret]),
        :remove_cookie_options,
        :cipher_secret,
        :hmac_secret,
        :old_cipher_secret,
        :old_hmac_secret
      )
      private_constant :Config

      # Exception class used when creating a session cookie that would exceed the
      # allowable cookie size limit.
      class CookieTooLarge < RodaError
      end

      # Split given secret into a cipher secret and an hmac secret.
      def self.split_secret(name, secret)
        raise RodaError, "sessions plugin :#{name} option must be a String" unless secret.is_a?(String)
        raise RodaError, "invalid sessions plugin :#{name} option length: #{secret.bytesize}, must be >=64" unless secret.bytesize >= 64
        hmac_secret = secret = secret.b
        cipher_secret = secret.slice!(0, 32)
        [cipher_secret.freeze, hmac_secret.freeze]
      end

      def self.load_dependencies(app, opts=OPTS, **)
        app.plugin :_base64
        app.plugin :_json
      end

      # Configure the plugin, see Sessions for details on options.
      def self.configure(app, opts=OPTS)
        RodaPlugins.check_supported_opts("the sessions plugin", opts, PLUGIN_ARGUMENTS)

        if opts.has_key?(:per_cookie_cipher_secret)
          RodaPlugins.warn("Roda 4 will default to per cookie cipher secrets, remove the per_cookie_cipher_secret argument", uplevel: 1)
        end

        if opts.has_key?(:upgrade_from_rack_session_cookie_secret) || opts.has_key?(:upgrade_from_rack_session_cookie_key) || opts.has_key?(:upgrade_from_rack_session_cookie_options)
          RodaPlugins.warn("Support for upgrading rack session cookie sessions will be removed in Roda 4, remove the upgrade_from_rack_session_cookie_* arguments.", uplevel: 1)
        end

        if opts.has_key?(:gzip_over)
          RodaPlugins.warn("Support for compressing session data will be removed in Roda 4, remove the gzip_over argument.", uplevel: 1)
        end

        opts = (app.sessions_opts || {:key => 'roda.session'.freeze, :max_seconds=>86400*30, :max_idle_seconds=>86400*7, :pad_size=>32, :skip_within=>3600, :env_key=>'rack.session'}).merge(opts)
        config = Config.new(*opts.values_at(*Config.members))
        co = config.cookie_options = {:httponly=>true, :path=>'/'.freeze, :same_site=>:lax}.merge(config.cookie_options || OPTS).freeze
        config.remove_cookie_options = co.merge(:max_age=>'0', :expires=>Time.at(0))
        config.parser ||= app.json_parser
        config.serializer ||= app.json_serializer

        opts[:per_cookie_cipher_secret] = true unless opts.has_key?(:per_cookie_cipher_secret)

        if opts[:upgrade_from_rack_session_cookie_secret]
          opts[:upgrade_from_rack_session_cookie_key] ||= 'rack.session'
          rsco = opts[:upgrade_from_rack_session_cookie_options] = Hash[opts[:upgrade_from_rack_session_cookie_options] || OPTS]
          rsco[:path] ||= co[:path]
          rsco[:domain] ||= co[:domain]
        end

        secret = opts[:secret]
        config.cipher_secret, config.hmac_secret = split_secret(:secret, secret)
        if old_secret = opts[:old_secret]
          config.old_cipher_secret, config.old_hmac_secret = split_secret(:old_secret, old_secret)
        end

        case config.pad_size
        when nil
          # no changes
        when Integer
          raise RodaError, "invalid :pad_size: #{config.pad_size}, must be >=2, < 4096" unless config.pad_size >= 2 && config.pad_size < 4096
        else
          raise RodaError, "invalid pad_size argument: #{config.pad_size.inspect}, must be Integer or nil"
        end
        
        app.opts[:sessions] = config.to_h.merge(opts).freeze
        app.opts[:sessions_config] = config.freeze
        app.opts[:sessions_convert_symbols] = true unless app.opts.has_key?(:sessions_convert_symbols)
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :sessions, name: :sessions_opts)
        RodaPlugins.opt_attr_reader(self, :sessions_config)
      end

      module InstanceMethods
        # Clear data from the session, and update the request environment
        # so that the session cookie will use a new creation timestamp
        # instead of the previous creation timestamp.
        def clear_session
          session.clear
          env.delete('roda.session.created_at')
          env.delete('roda.session.updated_at')
          nil
        end

        private

        # If session information has been set in the request environment,
        # update the rack response headers to set the session cookie in
        # the response.
        def _roda_after_50__sessions(res)
          if res && (session = env[self.class.sessions_config.env_key])
            @_request.persist_session(res[1], session)
          end
        end
      end

      module RequestMethods
        # Load the session information from the cookie.  With the sessions
        # plugin, you must call this method to get the session, instead of
        # trying to access the session directly through the request environment.
        # For maximum compatibility with other software that uses rack sessions,
        # this method stores the session in 'rack.session' in the request environment,
        # but that does not happen until this method is called.
        def session
          @env[roda_class.sessions_config.env_key] ||= _load_session
        end

        # The time the session was originally created. nil if there is no active session.
        def session_created_at
          session
          Time.at(@env['roda.session.created_at']) if @env['roda.session.serialized']
        end

        # The time the session was last updated. nil if there is no active session.
        def session_updated_at
          session
          Time.at(@env['roda.session.updated_at']) if @env['roda.session.serialized']
        end

        # Persist the session data as a cookie.
        def persist_session(headers, session)
          config = roda_class.sessions_config

          if session.empty?
            if env['roda.session.serialized']
              # If session was submitted and is now empty, remove the cookie
              Rack::Utils.delete_cookie_header!(headers, config.key, config.remove_cookie_options)
            # else
              # If no session was submitted, and the session is empty
              # then there is no need to do anything
            end
          elsif cookie_value = _serialize_session(session)
            cookie = Hash[config.cookie_options]
            cookie[:value] = cookie_value
            cookie[:secure] = true if !cookie.has_key?(:secure) && ssl?

            before_size = if (set_cookie_before = headers[RodaResponseHeaders::SET_COOKIE]).is_a?(String)
              set_cookie_before.bytesize
            else
              0
            end

            Rack::Utils.set_cookie_header!(headers, config.key, cookie)

            cookie_size = case set_cookie_after = headers[RodaResponseHeaders::SET_COOKIE]
            when String
              # Rack < 3 always takes this branch, combines cookies into string, subtract previous size
              # Rack 3+ takes this branch if this is the first cookie set, in which case before size is 0
              set_cookie_after.bytesize - before_size
            else # when Array
              # Rack 3+ takes branch if this is not the first cookie set, and last element of the array
              # is most recently added cookie
              set_cookie_after.last.bytesize
            end

            if cookie_size >= 4096
              raise CookieTooLarge, "attempted to create cookie larger than 4096 bytes (bytes: #{cookie_size})"
            end
          end
          
          if env['roda.session.delete_rack_session_cookie']
            opts = roda_class.sessions_opts
            Rack::Utils.delete_cookie_header!(headers, opts[:upgrade_from_rack_session_cookie_key], opts[:upgrade_from_rack_session_cookie_options])
          end

          nil
        end

        private

        # Load the session by looking for the appropriate cookie, or falling
        # back to the rack session cookie if configured.
        def _load_session
          cs = cookies

          if data = cs[roda_class.sessions_config.key]
            _deserialize_session(data)
          elsif (key = roda_class.sessions_opts[:upgrade_from_rack_session_cookie_key]) && (data = cs[key])
            _deserialize_rack_session(data)
          end || {}
        end

        # If 'rack.errors' is set, write the error message to it.
        # This is used for errors that shouldn't be raised as exceptions,
        # such as improper session cookies.
        def _session_serialization_error(msg)
          return unless error_stream = @env['rack.errors']
          error_stream.puts(msg)
          nil
        end

        def _deserialize_rack_session(data)
          opts = roda_class.sessions_opts
          data, digest = data.split("--", 2)
          unless digest
            return _session_serialization_error("Not decoding Rack::Session::Cookie session: invalid format")
          end
          unless Rack::Utils.secure_compare(digest, OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, opts[:upgrade_from_rack_session_cookie_secret], data))
            return _session_serialization_error("Not decoding Rack::Session::Cookie session: HMAC invalid")
          end

          begin
            session = Marshal.load(data.unpack('m').first)
          rescue
            return _session_serialization_error("Error decoding Rack::Session::Cookie session: not base64 encoded marshal dump")
          end

          env['roda.session.delete_rack_session_cookie'] = true

          session.delete("session_id")

          env['roda.session.serialized'] = data = opts[:serializer].call(session)
          env['roda.session.created_at'] = Time.now.to_i
          opts[:parser].call(data)
        end

        # Interpret given cookie data as a session
        def _deserialize_session(data)
          config = roda_class.sessions_config

          begin
            data = Base64_.urlsafe_decode64(data)
          rescue ArgumentError
            return _session_serialization_error("Unable to decode session: invalid base64")
          end

          case version = data.getbyte(0)
          when 1
            per_cookie_secret = true
            # minimum length (1+32+16+12+32) (version+random_data+cipher_iv+minimum session+hmac)
            # 1 : version
            # 32 : random_data (if per_cookie_cipher_secret)
            # 16 : cipher_iv
            # 12 : minimum_session
            #      2 : bitmap for gzip + padding info
            #      4 : creation time
            #      4 : update time
            #      2 : data
            # 32 : HMAC-SHA-256
            min_data_length = 93
          when 0
            per_cookie_secret = false
            min_data_length = 61
          when nil
            return _session_serialization_error("Unable to decode session: no data")
          else
            return _session_serialization_error("Unable to decode session: version marker unsupported")
          end

          length = data.bytesize
          if data.length < min_data_length
            return _session_serialization_error("Unable to decode session: data too short")
          end

          encrypted_data = data.slice!(0, length-32)
          hmac_data = encrypted_data+config.key
          cipher_secret = config.cipher_secret
          unless Rack::Utils.secure_compare(data, OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, config.hmac_secret, hmac_data))
            if config.old_hmac_secret && Rack::Utils.secure_compare(data, OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, config.old_hmac_secret, hmac_data))
              cipher_secret = config.old_cipher_secret
            else
              return _session_serialization_error("Not decoding session: HMAC invalid")
            end
          end

          # Remove version
          encrypted_data.slice!(0)

          if per_cookie_secret
            cipher_secret = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, cipher_secret, encrypted_data.slice!(0, 32))
          end
          cipher_iv = encrypted_data.slice!(0, 16)

          cipher = OpenSSL::Cipher.new("aes-256-ctr")

          # Not rescuing cipher errors.  If there is an error in the decryption, that's
          # either a bug in the plugin that needs to be fixed, or an attacker is already
          # able to forge a valid HMAC, in which case the error should be raised to
          # alert the application owner about the problem.
          cipher.decrypt
          cipher.key = cipher_secret
          cipher.iv = cipher_iv
          data = cipher.update(encrypted_data) << cipher.final

          bitmap, created_at, updated_at = data.unpack('vVV')
          padding_bytes = bitmap & 0x0fff
          now = Time.now.to_i
          if (max = config.max_seconds) && now > created_at + max
            return _session_serialization_error("Not returning session: maximum session time expired")
          end
          if (max = config.max_idle_seconds) && now > updated_at + max
            return _session_serialization_error("Not returning session: maximum session idle time expired")
          end

          data = data.slice(10+padding_bytes, data.bytesize)

          if bitmap & 0x1000 > 0
            data = Zlib::Inflate.inflate(data)
          end

          env = @env
          env['roda.session.created_at'] = created_at
          env['roda.session.updated_at'] = updated_at
          env['roda.session.serialized'] = data
          env['roda.session.version'] = version

          config.parser.call(data)
        end

        def _serialize_session(session)
          config = roda_class.sessions_config
          env = @env
          now = Time.now.to_i
          json_data = config.serializer.call(session).force_encoding(Encoding::ASCII_8BIT)

          if (serialized_session = env['roda.session.serialized']) &&
             ((roda_class.sessions_opts[:per_cookie_cipher_secret] ? 1 : 0) == env['roda.session.version']) &&
             (updated_at = env['roda.session.updated_at']) &&
             (now - updated_at < config.skip_within) &&
             (serialized_session == json_data)
            return
          end

          bitmap = 0
          json_length = json_data.bytesize
          gzip_over = roda_class.sessions_opts[:gzip_over]

          if gzip_over && json_length > gzip_over
            json_data = Zlib.deflate(json_data)
            json_length = json_data.bytesize
            bitmap |= 0x1000
          end

          # When calculating padding bytes to use, include 10 bytes for bitmap and
          # session create/update times, so total size of encrypted data is a
          # multiple of pad_size.
          if (pad_size = config.pad_size) && (padding_bytes = (json_length+10) % pad_size) != 0
            padding_bytes = pad_size - padding_bytes
            bitmap |= padding_bytes
            padding_data = SecureRandom.random_bytes(padding_bytes)
          end

          session_create_time = env['roda.session.created_at']
          serialized_data = [bitmap, session_create_time||now, now].pack('vVV')

          serialized_data << padding_data if padding_data
          serialized_data << json_data

          cipher_secret = config.cipher_secret
          if roda_class.sessions_opts[:per_cookie_cipher_secret]
            version = "\1"
            per_cookie_secret_base = SecureRandom.random_bytes(32)
            cipher_secret = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, cipher_secret, per_cookie_secret_base)
          else
            version = "\0"
          end

          cipher = OpenSSL::Cipher.new("aes-256-ctr")
          cipher.encrypt
          cipher.key = cipher_secret
          cipher_iv = cipher.random_iv
          encrypted_data = cipher.update(serialized_data) << cipher.final

          data = String.new
          data << version
          data << per_cookie_secret_base if per_cookie_secret_base
          data << cipher_iv
          data << encrypted_data
          data << OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, config.hmac_secret, data+config.key)

          data = Base64_.urlsafe_encode64(data)

          if data.bytesize >= 4096
            raise CookieTooLarge, "attempted to create cookie larger than 4096 bytes (bytes: #{data.bytesize})"
          end

          data
        end
      end
    end

    register_plugin(:sessions, Sessions)
  end
end
