# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The shape_friendly plugin makes the scope, request, and response objects
    # used by Roda friendly to object shapes, which can result in better
    # performance on modern versions of Ruby, especially when the JIT compiler
    # is enabled. All plugins shipped with Roda integrate with this plugin.
    #
    # In order for this behavior to be beneficial for your application, you
    # need to either avoid setting instance variables inside your routing
    # tree, or you need to register each instance variable used, to ensure
    # that all instances have the same shape.
    #
    # If you want to avoid using instance variables in your routing tree, you
    # can switch to using local variables. If using the render plugin, you can
    # pass data from your routing tree to your views using the +:locals+ option.
    # When passing data from your routing tree to other routing trees, such as
    # when using the hash_branches plugin, you can use the shared_vars plugin,
    # which stores the data in the Rack environment.
    #
    # To register instance variables set in your applications routing tree,
    # use a +:scope_instance_variables+ option when loading the plugin,
    # listing the instance variable symbols you are setting in the route
    # block scope:
    #
    #   class MyApp < Roda
    #     plugin :shape_friendly, scope_instance_variables: [:@var1, @:var2]
    #
    #     route do |r|
    #       r.root do
    #         @var1 = "a"
    #         @var1.inspect
    #       end
    #
    #       @var2 = "b"
    #       @var2.inspect
    #     end
    #   end
    #
    # When developing external plugins, you can set one of three constants in
    # the plugin module to integrate with this plugin to support shape friendly
    # behavior:
    #
    # * +SCOPE_INSTANCE_VARIABLES+: For instance variables set in +InstanceMethods+.
    # * +REQUEST_INSTANCE_VARIABLES+: For instance variables set in +RequestMethods+.
    # * +RESPONSE_INSTANCE_VARIABLES+: For instance variables set in +ResponseMethods+.
    #
    # These constants are set in the plugin module, not in the plugin's
    # +InstanceMethods+, +RequestMethods+, or +ResponseMethods+ modules, to
    # avoid pollution of the related namespaces in the class loading the plugin.
    module ShapeFriendly
      # This is used by the base support and not by this plugin.
      RESPONSE_INSTANCE_VARIABLES = [:@status].freeze

      # Set the Roda application to create the private
      # _initialize_nil_instance_variables for the plugin to use.
      def self.configure(app, opts=OPTS)
        if scope_ivs = opts[:scope_instance_variables]
          app.opts[:shape_friendly_scope_instance_variables] = Array(scope_ivs).dup.freeze
        end

        app.instance_exec do
          def_initialize_nil_instance_variables(app, :SCOPE_INSTANCE_VARIABLES)
          def_initialize_nil_instance_variables(app::RodaRequest, :REQUEST_INSTANCE_VARIABLES)
          def_initialize_nil_instance_variables(app::RodaResponse, :RESPONSE_INSTANCE_VARIABLES)

          # Avoid overhead of super call if possible
          include(instance_method(:initialize).owner == Roda::RodaPlugins::Base::InstanceMethods ? OptimizedInstanceMethods : UnoptimizedInstanceMethods)
          app::RodaRequest.send(:include, app::RodaRequest.instance_method(:initialize).owner == Roda::RodaPlugins::Base::RequestMethods ? OptimizedRequestMethods : UnoptimizedRequestMethods)
          app::RodaResponse.send(:include, app::RodaResponse.instance_method(:initialize).owner == Roda::RodaPlugins::Base::ResponseMethods ? OptimizedResponseMethods : UnoptimizedResponseMethods)
        end
      end

      module ClassMethods
        # Automatically refresh the instance variables used if the plugin
        # sets instance variables.
        def plugin(plugin, *args, &block)
          super
          plugin = RodaPlugins.load_plugin(plugin) if plugin.is_a?(Symbol)
          [
            [self, :SCOPE_INSTANCE_VARIABLES],
            [self::RodaRequest, :REQUEST_INSTANCE_VARIABLES],
            [self::RodaResponse, :RESPONSE_INSTANCE_VARIABLES],
          ].each do |klass, ivs_const|
            if plugin.const_defined?(ivs_const)
              def_initialize_nil_instance_variables(klass, ivs_const)
            end
          end
          nil
        end
        # :nocov:
        ruby2_keywords(:plugin) if respond_to?(:ruby2_keywords, true)
        # :nocov:

        private

        # If there are any intance variables configured in one of the plugins
        # (looking for the +const+ constant in the plugin), override the
        # private _initialize_nil_instance_variables method for the class,
        # and have it initialize each instance variable to nil. 
        def def_initialize_nil_instance_variables(klass, const)
          ivs = []

          plugins.each do |mod|
            ivs.concat(mod.const_get(const)) if mod.const_defined?(const)
          end

          if const == :SCOPE_INSTANCE_VARIABLES && (scope_ivs = opts[:shape_friendly_scope_instance_variables])
            ivs.concat(scope_ivs)
          end

          ivs.each do |iv|
            unless /\A@[a-z_][a-z0-9_]*\z/.match(iv)
              raise RodaError, "invalid scope instance variable used"
            end
          end

          unless ivs.empty?
            ivs.uniq!

            klass.class_eval(<<-RUBY, __FILE__, __LINE__+1)
              def _initialize_nil_instance_variables
                #{ivs.reverse.join(" = ")} = nil
              end
              private :_initialize_nil_instance_variables
              alias _initialize_nil_instance_variables _initialize_nil_instance_variables
            RUBY
            nil
          end
        end
      end

      # :nocov:
      if RUBY_VERSION >= '4.0'
      # :nocov:
        module InstanceMethods
          private

          def instance_variables_to_inspect
            instance_variables.reject{|v| instance_variable_get(v).nil?}
          end
        end
      end

      module OptimizedInstanceMethods
        # Initialize configured instance variables to nil.
        def initialize(env)
          _initialize_nil_instance_variables
          klass = self.class
          @_request = klass::RodaRequest.new(self, env)
          @_response = klass::RodaResponse.new
        end

        private

        def _initialize_nil_instance_variables
          nil
        end
      end

      module UnoptimizedInstanceMethods
        # Initialize configured instance variables to nil.
        def initialize(env)
          _initialize_nil_instance_variables
          super
        end

        private

        def _initialize_nil_instance_variables
          nil
        end
      end

      module OptimizedRequestMethods
        # Initialize configured instance variables to nil.
        def initialize(scope, env)
          _initialize_nil_instance_variables
          @scope = scope
          @captures = []
          @remaining_path = _remaining_path(env)
          @env = env
        end

        private

        def _initialize_nil_instance_variables
          nil
        end
      end

      module UnoptimizedRequestMethods
        # Initialize configured instance variables to nil.
        def initialize(scope, env)
          _initialize_nil_instance_variables
          super
        end

        private

        def _initialize_nil_instance_variables
          nil
        end
      end

      module OptimizedResponseMethods
        def initialize
          _initialize_nil_instance_variables
          @headers = _initialize_headers
          @body    = []
          @length  = 0
        end
      end

      module UnoptimizedResponseMethods
        # Initialize configured instance variables to nil.
        def initialize
          _initialize_nil_instance_variables
          super
        end
      end

      # For response methods, there is no default definition for
      # _initialize_nil_instance_variables, as the plugin will always
      # define a method in the class it is loaded into.
    end

    register_plugin(:shape_friendly, ShapeFriendly)
  end
end
