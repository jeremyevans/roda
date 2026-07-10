# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The host_routing plugin adds support for more routing requests based on
    # the requested host.  It also adds predicate methods for checking
    # whether a request was requested with the given host.
    #
    # When loading the plugin, you pass a block, which is used for configuring
    # the plugin.  For example, if you want to treat requests to api.example.com
    # or api2.example.com as api requests, and treat other requests as www
    # requests, you could use:
    #
    #   plugin :host_routing do |hosts|
    #     hosts.to :api, "api.example.com", "api2.example.com"
    #     hosts.default :www
    #   end
    #
    # With this configuration, in your routing tree, you can call the +r.api+ and
    # +r.www+ methods for dispatching to routing blocks only for those types of
    # requests:
    #
    #   route do |r|
    #     r.api do
    #       # requests to api.example.com or api2.example.com
    #     end
    #
    #     r.www do
    #       # requests to other domains
    #     end
    #   end
    #
    # In addition to the routing methods, predicate methods are also added to the
    # request object:
    #
    #   route do |r|
    #     "#{r.api?}-#{r.www?}"
    #   end
    #   # Requests to api.example.com or api2.example.com return "true-false"
    #   # Other requests return "false-true"
    #
    # If the +:scope_predicates+ plugin option is given, predicate methods are also
    # created in route block scope:
    #
    #   plugin :host_routing, scope_predicates: true do |hosts|
    #     hosts.to :api, "api.example.com"
    #     hosts.default :www
    #   end
    #
    #   route do |r|
    #     "#{api?}-#{www?}"
    #   end
    #
    # To handle hosts that match a certain format (such as all subdomains),
    # where the specific host names are not known up front, you can provide a block
    # when calling +hosts.default+. This block is passed the host name, or an empty
    # string if no host name is provided, and is evaluated in route block scope.
    # When using this support, you should also call +hosts.register+
    # to register host types that could be returned by the block.  For example, to
    # handle api subdomains differently:
    #
    #   plugin :host_routing do |hosts|
    #     hosts.to :api, "api.example.com"
    #     hosts.register :api_sub
    #     hosts.default :www do |host|
    #       :api_sub if host.end_with?(".api.example.com")
    #     end
    #   end
    #
    # This plugin uses the host method on the request to get the hostname (this method
    # is defined by Rack).
    module HostRouting
      REQUEST_INSTANCE_VARIABLES = [:@_host_routing_host].freeze

      # Setup the host routing support.  The block yields an object used to
      # configure the plugin.  Options:
      #
      # :scope_predicates :: Setup predicate methods in route block scope
      #                      in addition to request scope.
      def self.configure(app, opts=OPTS, &block)
        hosts, host_hash, default_block, default_host = DSL.new.process(&block)
        app.opts[:host_routing_hash] = host_hash
        app.opts[:host_routing_default_host] = default_host

        app.send(:define_method, :_host_routing_default, &default_block) if default_block

        app::RodaRequest.class_exec do
          hosts.each do |host|
            host_sym = host.to_sym
            define_method(host_sym){|&blk| always(&blk) if _host_routing_host == host}
            alias_method host_sym, host_sym

            meth = :"#{host}?"
            define_method(meth){_host_routing_host == host}
            alias_method meth, meth
          end
        end

        if opts[:scope_predicates]
          app.class_exec do
            hosts.each do |host|
              meth = :"#{host}?"
              define_method(meth){@_request.send(meth)}
              alias_method meth, meth
            end
          end
        end
      end

      class DSL
        def initialize
          @hosts = []
          @host_hash = {}
        end

        # Run the DSL for the given block.
        def process(&block)
          instance_exec(self, &block)

          if !@default_host
            raise RodaError, "must call default method inside host_routing plugin block to set default host"
          end

          @hosts.concat(@host_hash.values)
          @hosts << @default_host
          @hosts.uniq!
          [@hosts.freeze, @host_hash.freeze, @default_block, @default_host].freeze
        end
        
        # Register hosts that can be returned.  This is only needed if
        # calling register with a block, where the block can return
        # a value that doesn't match a host given to +to+ or +default+.
        def register(*hosts)
          @hosts = hosts
        end

        # Treat all given hostnames as routing to the give host.
        def to(host, *hostnames)
          hostnames.each do |hostname|
            @host_hash[hostname] = host
          end
        end

        # Register the default hostname.  If a block is provided, it is
        # called with the host if there is no match for one of the hostnames
        # provided to +to+.  If the block returns nil/false, the hostname
        # given to this method is used.
        def default(hostname, &block)
          @default_host = hostname
          @default_block = block
        end
      end
      private_constant :DSL

      module InstanceMethods
        # Handle case where plugin is used without providing a block to
        # +hosts.default+.  This returns nil, ensuring that the hostname
        # provided to +hosts.default+ will be used.
        def _host_routing_default(_)
          nil
        end
      end

      module RequestMethods
        private

        # Cache the host to use in the host routing support, so the processing
        # is only done once per request.
        def _host_routing_host
          @_host_routing_host ||= _get_host_routing_host
        end

        # Determine the host to use for the host routing support.  Tries the
        # following, in order:
        #
        # * An exact match for a hostname given in +hosts.to+
        # * The return value of the +hosts.default+ block, if given
        # * The default value provided in the +hosts.default+ call
        def _get_host_routing_host
          host = self.host || ""

          roda_class.opts[:host_routing_hash][host] ||
            scope._host_routing_default(host) ||
            roda_class.opts[:host_routing_default_host]
        end
      end
    end

    register_plugin(:host_routing, HostRouting)
  end
end
