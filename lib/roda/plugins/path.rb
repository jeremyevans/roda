class Roda
  module RodaPlugins
    # The path plugin adds support for named paths.  Using the +path+ class method, you can
    # easily create <tt>*_path</tt> instance methods for each named path.  Those instance
    # methods can then be called if you need to get the path for a form action, link,
    # redirect, or anything else.  Example:
    #
    #   plugin :path
    #   path :foo, '/foo'
    #   path :bar do |bar|
    #     "/bar/#{bar.id}"
    #   end
    #
    #   route do |r|
    #     r.post 'bar' do
    #       bar = Bar.create(r.params['bar'])
    #       r.redirect bar_path(bar)
    #     end
    #   end
    #
    # The path method accepts the following options:
    #
    # :add_script_name :: Prefix the path generated with SCRIPT_NAME.
    # :name :: Provide a different name for the method, instead of using <tt>*_path</tt>.
    # :url :: Create a url method in addition to the path method, which will prefix the string generated
    #         with the appropriate scheme, host, and port.  If true, creates a <tt>*_url</tt>
    #         method.  If a Symbol or String, uses the value as the url method name.
    # :url_only :: Do not create a path method, just a url method.
    #
    # Note that if :add_script_name, :url, or :url_only is used, this will also create a <tt>_*_path</tt>
    # method.  This is necessary in order to support path methods that accept blocks, as you can't pass
    # a block to a block that is instance_execed.
    module Path
      DEFAULT_PORTS = {'http' => 80, 'https' => 443}.freeze
      OPTS          = {}.freeze

      module ClassMethods
        # Create a new instance method for the named path.  See plugin module documentation for options.
        def path(name, path=nil, opts=OPTS, &block)
          if path.is_a?(Hash)
            raise RodaError,  "cannot provide two option hashses to Roda.path" unless opts.empty?
            opts = path
            path = nil
          end

          raise RodaError,  "cannot provide both path and block to Roda.path" if path && block
          raise RodaError,  "must provide either path or block to Roda.path" unless path || block

          if path
            path = path.dup.freeze
            block = lambda{path}
          end

          meth = opts[:name] || "#{name}_path"
          url = opts[:url]
          add_script_name = opts[:add_script_name]

          if add_script_name || url || opts[:url_only]
            _meth = "_#{meth}"
            define_method(_meth, &block)
          end

          unless opts[:url_only]
            if add_script_name
              define_method(meth) do |*a, &blk|
                request.script_name.to_s + send(_meth, *a, &blk)
              end
            else
              define_method(meth, &block)
            end
          end

          if url || opts[:url_only]
            url_meth = if url.is_a?(String) || url.is_a?(Symbol)
              url
            else
              "#{name}_url"
            end

            url_block = lambda do |*a, &blk|
              r      = request
              scheme = r.scheme
              port   = r.port
              uri    = ["#{scheme}://#{r.host}#{":#{port}" unless DEFAULT_PORTS[scheme] == port}"]
              uri << request.script_name.to_s if add_script_name
              uri << send(_meth, *a, &blk)
              File.join(uri)
            end

            define_method(url_meth, &url_block)
          end

          nil
        end
      end
    end

    register_plugin(:path, Path)
  end
end
