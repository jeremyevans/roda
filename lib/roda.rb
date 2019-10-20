# frozen-string-literal: true

require "rack"
require "thread"
require_relative "roda/version"

# The main class for Roda.  Roda is built completely out of plugins, with the
# default plugin being Roda::RodaPlugins::Base, so this class is mostly empty
# except for some constants.
class Roda
  # Error class raised by Roda
  class RodaError < StandardError; end

  # A thread safe cache class, offering only #[] and #[]= methods,
  # each protected by a mutex.
  class RodaCache
    # Create a new thread safe cache.
    def initialize
      @mutex = Mutex.new
      @hash = {}
    end

    # Make getting value from underlying hash thread safe.
    def [](key)
      @mutex.synchronize{@hash[key]}
    end

    # Make setting value in underlying hash thread safe.
    def []=(key, value)
      @mutex.synchronize{@hash[key] = value}
    end

    private

    # Create a copy of the cache with a separate mutex.
    def initialize_copy(other)
      @mutex = Mutex.new
      other.instance_variable_get(:@mutex).synchronize do
        @hash = other.instance_variable_get(:@hash).dup
      end
    end
  end

  # Base class used for Roda requests.  The instance methods for this
  # class are added by Roda::RodaPlugins::Base::RequestMethods, the
  # class methods are added by Roda::RodaPlugins::Base::RequestClassMethods.
  class RodaRequest < ::Rack::Request
    @roda_class = ::Roda
    @match_pattern_cache = ::Roda::RodaCache.new
  end

  # Base class used for Roda responses.  The instance methods for this
  # class are added by Roda::RodaPlugins::Base::ResponseMethods, the class
  # methods are added by Roda::RodaPlugins::Base::ResponseClassMethods.
  class RodaResponse
    @roda_class = ::Roda
  end

  @app = nil
  @inherit_middleware = true
  @middleware = []
  @opts = {}
  @raw_route_block = nil
  @route_block = nil
  @rack_app_route_block = nil

  # Module in which all Roda plugins should be stored. Also contains logic for
  # registering and loading plugins.
  module RodaPlugins
    OPTS = {}.freeze
    EMPTY_ARRAY = [].freeze

    # Stores registered plugins
    @plugins = RodaCache.new

    class << self
      # Make warn a public method, as it is used for deprecation warnings.
      # Roda::RodaPlugins.warn can be overridden for custom handling of
      # deprecation warnings.
      public :warn
    end

    # If the registered plugin already exists, use it.  Otherwise,
    # require it and return it.  This raises a LoadError if such a
    # plugin doesn't exist, or a RodaError if it exists but it does
    # not register itself correctly.
    def self.load_plugin(name)
      h = @plugins
      unless plugin = h[name]
        require "roda/plugins/#{name}"
        raise RodaError, "Plugin #{name} did not register itself correctly in Roda::RodaPlugins" unless plugin = h[name]
      end
      plugin
    end

    # Register the given plugin with Roda, so that it can be loaded using #plugin
    # with a symbol.  Should be used by plugin files. Example:
    #
    #   Roda::RodaPlugins.register_plugin(:plugin_name, PluginModule)
    def self.register_plugin(name, mod)
      @plugins[name] = mod
    end

    # Deprecate the constant with the given name in the given module,
    # if the ruby version supports it.
    def self.deprecate_constant(mod, name)
      # :nocov:
      if RUBY_VERSION >= '2.3'
        mod.deprecate_constant(name)
      end
      # :nocov:
    end

    # The base plugin for Roda, implementing all default functionality.
    # Methods are put into a plugin so future plugins can easily override
    # them and call super to get the default behavior.
    module Base
      # Class methods for the Roda class.
      module ClassMethods
        # The rack application that this class uses.
        def app
          @app || build_rack_app
        end

        # Whether middleware from the current class should be inherited by subclasses.
        # True by default, should be set to false when using a design where the parent
        # class accepts requests and uses run to dispatch the request to a subclass.
        attr_accessor :inherit_middleware

        # The settings/options hash for the current class.
        attr_reader :opts

        # The route block that this class uses.
        attr_reader :route_block

        # Call the internal rack application with the given environment.
        # This allows the class itself to be used as a rack application.
        # However, for performance, it's better to use #app to get direct
        # access to the underlying rack app.
        def call(env)
          app.call(env)
        end

        # Clear the middleware stack
        def clear_middleware!
          @middleware.clear
          @app = nil
        end

        # Define an instance method using the block with the provided name and
        # expected arity.  If the name is given as a Symbol, it is used directly.
        # If the name is given as a String, a unique name will be generated using
        # that string.  The expected arity should be either 0 (no arguments),
        # 1 (single argument), or :any (any number of arguments).
        #
        # If the :check_arity app option is not set to false, Roda will check that
        # the arity of the block matches the expected arity, and compensate for
        # cases where it does not.  If it is set to :warn, Roda will warn in the
        # cases where the arity does not match what is expected.
        #
        # If the expected arity is :any, Roda must perform a dynamic arity check
        # when the method is called, which can hurt performance even in the case
        # where the arity matches.  The :check_dynamic_arity app option can be
        # set to false to turn off the dynamic arity checks.  The
        # :check_dynamic_arity app option can be to :warn to warn if Roda needs
        # to adjust arity dynamically.
        #
        # Roda only checks arity for regular blocks, not lambda blocks, as the
        # fixes Roda uses for regular blocks would not work for lambda blocks.
        #
        # Roda does not support blocks with required keyword arguments if the
        # expected arity is 0 or 1.
        def define_roda_method(meth, expected_arity, &block)
          if meth.is_a?(String)
            meth = roda_method_name(meth)
          end
          call_meth = meth

          if (check_arity = opts.fetch(:check_arity, true)) && !block.lambda?
            required_args, optional_args, rest, keyword = _define_roda_method_arg_numbers(block)

            if keyword == :required && (expected_arity == 0 || expected_arity == 1)
              raise RodaError, "cannot use block with required keyword arguments when calling define_roda_method with expected arity #{expected_arity}"
            end

            case expected_arity
            when 0
              unless required_args == 0
                if check_arity == :warn
                  RodaPlugins.warn "Arity mismatch in block passed to define_roda_method. Expected Arity 0, but arguments required for #{block.inspect}"
                end
                b = block
                block = lambda{instance_exec(&b)} # Fallback
              end
            when 1
              if required_args == 0 && optional_args == 0 && !rest
                if check_arity == :warn
                  RodaPlugins.warn "Arity mismatch in block passed to define_roda_method. Expected Arity 1, but no arguments accepted for #{block.inspect}"
                end
                temp_method = roda_method_name("temp")
                class_eval("def #{temp_method}(_) #{meth =~ /\A\w+\z/ ? "#{meth}_arity" : "send(:\"#{meth}_arity\")"} end", __FILE__, __LINE__)
                alias_method meth, temp_method
                undef_method temp_method
                private meth
                meth = :"#{meth}_arity"
              elsif required_args > 1
                b = block
                block = lambda{|r| instance_exec(r, &b)} # Fallback
              end
            when :any
              if check_dynamic_arity = opts.fetch(:check_dynamic_arity, check_arity)
                if keyword
                  # Complexity of handling keyword arguments using define_method is too high,
                  # Fallback to instance_exec in this case.
                  b = block
                  if RUBY_VERSION >= '2.7'
                    block = eval('lambda{|*a, **kw| instance_exec(*a, **kw, &b)}', nil, __FILE__, __LINE__) # Keyword arguments fallback
                  else
                    block = lambda{|*a| instance_exec(*a, &b)} # Keyword arguments fallback
                  end
                else
                  arity_meth = meth
                  meth = :"#{meth}_arity"
                end
              end
            else
              raise RodaError, "unexpected arity passed to define_roda_method: #{expected_arity.inspect}"
            end
          end

          define_method(meth, &block)
          private meth

          if arity_meth
            required_args, optional_args, rest, keyword = _define_roda_method_arg_numbers(instance_method(meth))
            max_args = required_args + optional_args
            define_method(arity_meth) do |*a|
              arity = a.length
              if arity > required_args
                if arity > max_args && !rest
                  if check_dynamic_arity == :warn
                    RodaPlugins.warn "Dynamic arity mismatch in block passed to define_roda_method. At most #{max_args} arguments accepted, but #{arity} arguments given for #{block.inspect}"
                  end
                  a = a.slice(0, max_args)
                end
              elsif arity < required_args
                if check_dynamic_arity == :warn
                  RodaPlugins.warn "Dynamic arity mismatch in block passed to define_roda_method. #{required_args} args required, but #{arity} arguments given for #{block.inspect}"
                end
                a.concat([nil] * (required_args - arity))
              end

              send(meth, *a)
            end
            private arity_meth
          end

          call_meth
        end

        # Expand the given path, using the root argument as the base directory.
        def expand_path(path, root=opts[:root])
          ::File.expand_path(path, root)
        end

        # Freeze the internal state of the class, to avoid thread safety issues at runtime.
        # It's optional to call this method, as nothing should be modifying the
        # internal state at runtime anyway, but this makes sure an exception will
        # be raised if you try to modify the internal state after calling this.
        #
        # Note that freezing the class prevents you from subclassing it, mostly because
        # it would cause some plugins to break.
        def freeze
          return self if frozen?

          unless opts[:subclassed]
            # If the _roda_run_main_route instance method has not been overridden,
            # make it an alias to _roda_main_route for performance
            if instance_method(:_roda_run_main_route).owner == InstanceMethods
              class_eval("alias _roda_run_main_route _roda_main_route")
            end
            self::RodaResponse.class_eval do
              if instance_method(:set_default_headers).owner == ResponseMethods &&
                 instance_method(:default_headers).owner == ResponseMethods

                def set_default_headers
                  @headers['Content-Type'] ||= 'text/html'
                end
              end
            end

            if @middleware.empty? && use_new_dispatch_api?
              plugin :direct_call
            end
          end

          build_rack_app
          @opts.freeze
          @middleware.freeze

          super
        end

        # Rebuild the _roda_before and _roda_after methods whenever a plugin might
        # have added a _roda_before_* or _roda_after_* method.
        def include(*a)
          res = super
          def_roda_before
          def_roda_after
          res
        end

        # When inheriting Roda, copy the shared data into the subclass,
        # and setup the request and response subclasses.
        def inherited(subclass)
          raise RodaError, "Cannot subclass a frozen Roda class" if frozen?

          # Mark current class as having been subclassed, as some optimizations
          # depend on the class not being subclassed
          opts[:subclassed] = true

          super
          subclass.instance_variable_set(:@inherit_middleware, @inherit_middleware)
          subclass.instance_variable_set(:@middleware, @inherit_middleware ? @middleware.dup : [])
          subclass.instance_variable_set(:@opts, opts.dup)
          subclass.opts.delete(:subclassed)
          subclass.opts.to_a.each do |k,v|
            if (v.is_a?(Array) || v.is_a?(Hash)) && !v.frozen?
              subclass.opts[k] = v.dup
            end
          end
          if block = @raw_route_block
            subclass.route(&block)
          end

          request_class = Class.new(self::RodaRequest)
          request_class.roda_class = subclass
          request_class.match_pattern_cache = RodaCache.new
          subclass.const_set(:RodaRequest, request_class)

          response_class = Class.new(self::RodaResponse)
          response_class.roda_class = subclass
          subclass.const_set(:RodaResponse, response_class)
        end

        # Load a new plugin into the current class.  A plugin can be a module
        # which is used directly, or a symbol representing a registered plugin
        # which will be required and then used. Returns nil.
        #
        # Note that you should not load plugins into a Roda class after the
        # class has been subclassed, as doing so can break the subclasses.
        #
        #   Roda.plugin PluginModule
        #   Roda.plugin :csrf
        def plugin(plugin, *args, &block)
          raise RodaError, "Cannot add a plugin to a frozen Roda class" if frozen?
          plugin = RodaPlugins.load_plugin(plugin) if plugin.is_a?(Symbol)
          plugin.load_dependencies(self, *args, &block) if plugin.respond_to?(:load_dependencies)
          include(plugin::InstanceMethods) if defined?(plugin::InstanceMethods)
          extend(plugin::ClassMethods) if defined?(plugin::ClassMethods)
          self::RodaRequest.send(:include, plugin::RequestMethods) if defined?(plugin::RequestMethods)
          self::RodaRequest.extend(plugin::RequestClassMethods) if defined?(plugin::RequestClassMethods)
          self::RodaResponse.send(:include, plugin::ResponseMethods) if defined?(plugin::ResponseMethods)
          self::RodaResponse.extend(plugin::ResponseClassMethods) if defined?(plugin::ResponseClassMethods)
          plugin.configure(self, *args, &block) if plugin.respond_to?(:configure)
          @app = nil
        end

        # Setup routing tree for the current Roda application, and build the
        # underlying rack application using the stored middleware. Requires
        # a block, which is yielded the request.  By convention, the block
        # argument should be named +r+.  Example:
        #
        #   Roda.route do |r|
        #     r.root do
        #       "Root"
        #     end
        #   end
        #
        # This should only be called once per class, and if called multiple
        # times will overwrite the previous routing.
        def route(&block)
          unless block
            RodaPlugins.warn "no block passed to Roda.route"
            return
          end

          @raw_route_block = block
          @route_block = block = convert_route_block(block)
          @rack_app_route_block = block = rack_app_route_block(block)
          public define_roda_method(:_roda_main_route, 1, &block)
          @app = nil
        end

        # Add a middleware to use for the rack application.  Must be
        # called before calling #route to have an effect. Example:
        #
        #   Roda.use Rack::ShowExceptions
        def use(*args, &block)
          @middleware << [args, block].freeze
          @app = nil
        end

        private

        # Return the number of required argument, optional arguments,
        # whether the callable accepts any additional arguments,
        # and whether the callable accepts keyword arguments (true, false
        # or :required).
        def _define_roda_method_arg_numbers(callable)
          optional_args = 0
          rest = false
          keyword = false
          callable.parameters.map(&:first).each do |arg_type, _|
            case arg_type
            when :opt
              optional_args += 1
            when :rest
              rest = true
            when :keyreq
              keyword = :required
            when :key, :keyrest
              keyword ||= true
            end
          end
          arity = callable.arity
          if arity < 0
            arity = arity.abs - 1
          end
          required_args = arity
          arity -= 1 if keyword == :required

          if callable.is_a?(Proc) && !callable.lambda?
            optional_args -= arity
          end

          [required_args, optional_args, rest, keyword]
        end

        # The base rack app to use, before middleware is added.
        def base_rack_app_callable(new_api=true)
          if new_api
            lambda{|env| new(env)._roda_handle_main_route}
          else
            block = @rack_app_route_block
            lambda{|env| new(env).call(&block)}
          end
        end

        # Build the rack app to use
        def build_rack_app
          app = base_rack_app_callable(use_new_dispatch_api?)

          @middleware.reverse_each do |args, bl|
            mid, *args = args
            app = mid.new(app, *args, &bl)
            app.freeze if opts[:freeze_middleware]
          end

          @app = app
        end

        # Modify the route block to use for any route block provided as input,
        # which can include route blocks that are delegated to by the main route block.
        # Can be modified by plugins.
        def convert_route_block(block)
          block
        end

        # Build a _roda_before method that calls each _roda_before_* method
        # in order, if any _roda_before_* methods are defined. Also, rebuild
        # the route block if a _roda_before method is defined.
        def def_roda_before
          meths = private_instance_methods.grep(/\A_roda_before_\d\d/).sort
          unless meths.empty?
            plugin :_before_hook unless private_method_defined?(:_roda_before)
            if meths.length == 1
              class_eval("alias _roda_before #{meths.first}", __FILE__, __LINE__)
            else
              class_eval("def _roda_before; #{meths.join(';')} end", __FILE__, __LINE__)
            end
            private :_roda_before
          end
        end

        # Build a _roda_after method that calls each _roda_after_* method
        # in order, if any _roda_after_* methods are defined. Also, use
        # the internal after hook plugin if the _roda_after method is defined.
        def def_roda_after
          meths = private_instance_methods.grep(/\A_roda_after_\d\d/).sort
          unless meths.empty?
            plugin :error_handler unless private_method_defined?(:_roda_after)
            if meths.length == 1
              class_eval("alias _roda_after #{meths.first}", __FILE__, __LINE__)
            else
              class_eval("def _roda_after(res); #{meths.map{|s| "#{s}(res)"}.join(';')} end", __FILE__, __LINE__)
            end
            private :_roda_after
          end
        end

        # The route block to use when building the rack app (or other initial
        # entry point to the route block).
        # By default, modifies the rack app route block to support before hooks
        # if any before hooks are defined.
        # Can be modified by plugins.
        def rack_app_route_block(block)
          block
        end

        # Whether the new dispatch API should be used.
        def use_new_dispatch_api?
          # RODA4: remove this method
          ancestors.each do |mod|
            break if mod == InstanceMethods
            meths = mod.instance_methods(false)
            if meths.include?(:call) && !(meths.include?(:_roda_handle_main_route) || meths.include?(:_roda_run_main_route))
            RodaPlugins.warn <<WARNING
Falling back to using #call for dispatching for #{self}, due to #call override in #{mod}.
#{mod} should be fixed to adjust to Roda's new dispatch API, and override _roda_handle_main_route or _roda_run_main_route
WARNING
              return false
            end
          end

          true
        end

        method_num = 0
        method_num_mutex = Mutex.new
        # Return a unique method name symbol for the given suffix.
        define_method(:roda_method_name) do |suffix|
          :"_roda_#{suffix}_#{method_num_mutex.synchronize{method_num += 1}}"
        end
      end

      # Instance methods for the Roda class.
      #
      # In addition to the listed methods, the following two methods are available:
      #
      # request :: The instance of the request class related to this request.
      #            This is the same object yielded by Roda.route.
      # response :: The instance of the response class related to this request.
      module InstanceMethods
        # Create a request and response of the appropriate class
        def initialize(env)
          klass = self.class
          @_request = klass::RodaRequest.new(self, env)
          @_response = klass::RodaResponse.new
        end

        # Handle dispatching to the main route, catching :halt and handling
        # the result of the block.
        def _roda_handle_main_route
          catch(:halt) do
            r = @_request
            r.block_result(_roda_run_main_route(r))
            @_response.finish
          end
        end

        # Treat the given block as a routing block, catching :halt if
        # thrown by the block.
        def _roda_handle_route
          catch(:halt) do
            @_request.block_result(yield)
            @_response.finish
          end
        end

        # Default implementation of the main route, usually overridden
        # by Roda.route.
        def _roda_main_route(_)
        end

        # Run the main route block with the request.  Designed for
        # extension by plugins
        def _roda_run_main_route(r)
          _roda_main_route(r)
        end

        # Deprecated method for the previous main route dispatch API.
        def call(&block)
          # RODA4: Remove
          catch(:halt) do
            r = @_request
            r.block_result(instance_exec(r, &block)) # Fallback
            @_response.finish
          end
        end

        # Deprecated private alias for internal use
        alias _call call
        # RODA4: Remove
        private :_call

        # The environment hash for the current request. Example:
        #
        #   env['REQUEST_METHOD'] # => 'GET'
        def env
          @_request.env
        end

        # The class-level options hash.  This should probably not be
        # modified at the instance level. Example:
        #
        #   Roda.plugin :render
        #   Roda.route do |r|
        #     opts[:render_opts].inspect
        #   end
        def opts
          self.class.opts
        end

        attr_reader :_request # :nodoc:
        alias request _request
        remove_method :_request

        attr_reader :_response # :nodoc:
        alias response _response
        remove_method :_response

        # The session hash for the current request. Raises RodaError
        # if no session exists. Example:
        #
        #   session # => {}
        def session
          @_request.session
        end
      end

      # Class methods for RodaRequest
      module RequestClassMethods
        # Reference to the Roda class related to this request class.
        attr_accessor :roda_class

        # The cache to use for match patterns for this request class.
        attr_accessor :match_pattern_cache

        # Return the cached pattern for the given object.  If the object is
        # not already cached, yield to get the basic pattern, and convert the
        # basic pattern to a pattern that does not partial segments.
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
            if body.class == Array
              body.each{|string| res.write(string) }
            else
              res.write(body)
            end
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
        def real_remaining_path
          remaining_path
        end

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
          if remaining_path == "/" && is_get?
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

        # Match integer segment, and yield resulting value as an
        # integer.
        def _match_class_Integer
          consume(/\A\/(\d+)(?=\/|\z)/){|i| [i.to_i]}
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

        # Match the given symbol if any segment matches.
        def _match_symbol(sym=nil)
          rp = @remaining_path
          if rp.getbyte(0) == 47
            if last = rp.index('/', 1)
              if last > 1
                @captures << rp[1, last-1]
                @remaining_path = rp[last, rp.length]
              end
            elsif rp.length > 1
              @captures << rp[1,rp.length]
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
          when Array
            result
          when String
            result
          when nil, false
            # nothing
          else
            raise RodaError, "unsupported block result: #{result.inspect}"
          end
        end

        # Attempts to match the pattern to the current path.  If there is no
        # match, returns false without changes.  Otherwise, modifies
        # SCRIPT_NAME to include the matched path, removes the matched
        # path from PATH_INFO, and updates captures with any regex captures.
        def consume(pattern)
          if matchdata = remaining_path.match(pattern)
            @remaining_path = matchdata.post_match
            captures = matchdata.captures
            captures = yield(*captures) if block_given?
            @captures.concat(captures)
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
          remaining_path.empty?
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

        # Handle an unsupported matcher.
        def unsupported_matcher(matcher)
          raise RodaError, "unsupported matcher: #{matcher.inspect}"
        end
      end

      # Class methods for RodaResponse
      module ResponseClassMethods
        # Reference to the Roda class related to this response class.
        attr_accessor :roda_class

        # Since RodaResponse is anonymously subclassed when Roda is subclassed,
        # and then assigned to a constant of the Roda subclass, make inspect
        # reflect the likely name for the class.
        def inspect
          "#{roda_class.inspect}::RodaResponse"
        end
      end

      # Instance methods for RodaResponse
      module ResponseMethods
        DEFAULT_HEADERS = {"Content-Type" => "text/html".freeze}.freeze

        # The body for the current response.
        attr_reader :body

        # The hash of response headers for the current response.
        attr_reader :headers

        # The status code to use for the response.  If none is given, will use 200
        # code for non-empty responses and a 404 code for empty responses.
        attr_accessor :status

        # Set the default headers when creating a response.
        def initialize
          @headers = {}
          @body    = []
          @length  = 0
        end

        # Return the response header with the given key. Example:
        #
        #   response['Content-Type'] # => 'text/html'
        def [](key)
          @headers[key]
        end

        # Set the response header with the given key to the given value.
        #
        #   response['Content-Type'] = 'application/json'
        def []=(key, value)
          @headers[key] = value
        end

        # The default headers to use for responses.
        def default_headers
          DEFAULT_HEADERS
        end

        # Whether the response body has been written to yet.  Note
        # that writing an empty string to the response body marks
        # the response as not empty. Example:
        #
        #   response.empty? # => true
        #   response.write('a')
        #   response.empty? # => false
        def empty?
          @body.empty?
        end

        # Return the rack response array of status, headers, and body
        # for the current response.  If the status has not been set,
        # uses the return value of default_status if the body has
        # been written to, otherwise uses a 404 status.
        # Adds the Content-Length header to the size of the response body.
        #
        # Example:
        #
        #   response.finish
        #   #  => [200,
        #   #      {'Content-Type'=>'text/html', 'Content-Length'=>'0'},
        #   #      []]
        def finish
          b = @body
          set_default_headers
          h = @headers

          if b.empty?
            s = @status || 404
            if (s == 304 || s == 204 || (s >= 100 && s <= 199))
              h.delete("Content-Type")
            elsif s == 205
              h.delete("Content-Type")
              h["Content-Length"] = '0'
            else
              h["Content-Length"] ||= '0'
            end
          else
            s = @status || default_status
            h["Content-Length"] ||= @length.to_s
          end

          [s, h, b]
        end

        # Return the rack response array using a given body.  Assumes a
        # 200 response status unless status has been explicitly set,
        # and doesn't add the Content-Length header or use the existing
        # body.
        def finish_with_body(body)
          set_default_headers
          [@status || default_status, @headers, body]
        end

        # Return the default response status to be used when the body
        # has been written to. This is split out to make overriding
        # easier in plugins.
        def default_status
          200
        end

        # Show response class, status code, response headers, and response body
        def inspect
          "#<#{self.class.inspect} #{@status.inspect} #{@headers.inspect} #{@body.inspect}>"
        end

        # Set the Location header to the given path, and the status
        # to the given status.  Example:
        #
        #   response.redirect('foo', 301)
        #   response.redirect('bar')
        def redirect(path, status = 302)
          @headers["Location"] = path
          @status  = status
          nil
        end

        # Return the Roda class related to this response.
        def roda_class
          self.class.roda_class
        end

        # Write to the response body.  Returns nil.
        #
        #   response.write('foo')
        def write(str)
          s = str.to_s
          @length += s.bytesize
          @body << s
          nil
        end

        private

        # For each default header, if a header has not already been set for the
        # response, set the header in the response.
        def set_default_headers
          h = @headers
          default_headers.each do |k,v|
            h[k] ||= v
          end
        end
      end
    end
  end

  extend RodaPlugins::Base::ClassMethods
  plugin RodaPlugins::Base
end
