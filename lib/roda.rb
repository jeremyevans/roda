# frozen-string-literal: true

require "thread"
require_relative "roda/request"
require_relative "roda/response"
require_relative "roda/plugins"
require_relative "roda/cache"
require_relative "roda/version"

# The main class for Roda.  Roda is built completely out of plugins, with the
# default plugin being Roda::RodaPlugins::Base, so this class is mostly empty
# except for some constants.
class Roda
  # Error class raised by Roda
  class RodaError < StandardError; end

  @app = nil
  @inherit_middleware = true
  @middleware = []
  @opts = {}
  @raw_route_block = nil
  @route_block = nil
  @rack_app_route_block = nil

  module RodaPlugins
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

          # RODA4: Switch to false # :warn in last Roda 3 version
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
                alias_method meth, meth
                meth = :"#{meth}_arity"
              elsif required_args > 1
                if check_arity == :warn
                  RodaPlugins.warn "Arity mismatch in block passed to define_roda_method. Expected Arity 1, but multiple arguments required for #{block.inspect}"
                end
                b = block
                block = lambda{|r| instance_exec(r, &b)} # Fallback
              end
            when :any
              if check_dynamic_arity = opts.fetch(:check_dynamic_arity, check_arity)
                if keyword
                  # Complexity of handling keyword arguments using define_method is too high,
                  # Fallback to instance_exec in this case.
                  b = block
                  block = if RUBY_VERSION >= '2.7'
                    eval('lambda{|*a, **kw| instance_exec(*a, **kw, &b)}', nil, __FILE__, __LINE__) # Keyword arguments fallback
                  else
                    # :nocov:
                    lambda{|*a| instance_exec(*a, &b)} # Keyword arguments fallback
                    # :nocov:
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
          alias_method meth, meth

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
            alias_method arity_meth, arity_meth
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

                private

                alias set_default_headers set_default_headers
                def set_default_headers
                  @headers[RodaResponseHeaders::CONTENT_TYPE] ||= 'text/html'
                end
              end
            end

            if @middleware.empty? && use_new_dispatch_api?
              plugin :direct_call
            end

            if RUBY_VERSION > "2.4" && ([:on, :is, :_verb, :_match_class_String, :_match_class_Integer, :_match_string, :_match_regexp, :empty_path?, :if_match, :match, :_match_class]).all?{|m| self::RodaRequest.instance_method(m).owner == RequestMethods}
              plugin :_optimized_matching
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
          raise RodaError, "Invalid plugin type: #{plugin.class.inspect}" unless plugin.is_a?(Module)

          if !plugin.respond_to?(:load_dependencies) && !plugin.respond_to?(:configure) && (!args.empty? || block)
            # RODA4: switch from warning to error
            RodaPlugins.warn("Plugin #{plugin} does not accept arguments or a block, but arguments or a block was passed when loading this. This will raise an error in Roda 4.")
          end

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
        # :nocov:
        ruby2_keywords(:plugin) if respond_to?(:ruby2_keywords, true)
        # :nocov:

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
        # :nocov:
        ruby2_keywords(:use) if respond_to?(:ruby2_keywords, true)
        # :nocov:

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
            alias_method :_roda_before, :_roda_before
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
            alias_method :_roda_after, :_roda_after
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

        private

        # Convert the segment matched by the Integer matcher to an integer.
        def _convert_class_Integer(value)
          value.to_i
        end
      end
    end
  end

  extend RodaPlugins::Base::ClassMethods
  plugin RodaPlugins::Base
end
