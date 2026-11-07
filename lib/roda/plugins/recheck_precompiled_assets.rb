# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The recheck_precompiled_assets plugin enables checking for the precompiled asset metadata file.
    # You need to have already loaded the assets plugin with the +:precompiled+ option and the file
    # specified by the +:precompiled+ option must already exist in order to use the
    # recheck_precompiled_assets plugin.
    #
    # Any time you want to check whether the precompiled asset metadata file has changed and should be
    # reloaded, you can call the +recheck_precompiled_assets+ class method.  This method will check
    # whether the file has changed, and reload it if it has.  If you want to check for modifications on
    # every request, you can use +self.class.recheck_precompiled_assets+ inside your route block.
    module RecheckPrecompiledAssets
      # Thread safe wrapper for the compiled asset metadata hash.  Does not wrap all
      # hash methods, only a few that are used.
      class CompiledAssetsHash
        include Enumerable

        def initialize
          @hash = {}
          @mutex = Mutex.new
        end

        def [](key)
          @mutex.synchronize{@hash[key]}
        end

        def []=(key, value)
          @mutex.synchronize{@hash[key] = value}
        end

        def replace(hash)
          hash = hash.instance_variable_get(:@hash) if (CompiledAssetsHash === hash)
          @mutex.synchronize{@hash.replace(hash)}
          self
        end

        def each(&block)
          @mutex.synchronize{@hash.dup}.each(&block)
          self
        end

        def to_json(*args)
          @mutex.synchronize{@hash.dup}.to_json(*args)
        end
      end

      def self.load_dependencies(app)
        unless app.respond_to?(:assets_config) && app.assets_config.precompiled
          raise RodaError, "must load assets plugin with precompiled option before loading recheck_precompiled_assets plugin"
        end
        # Set mutex before overriding a method that uses it
        app::RodaRequest.instance_variable_set(:@_precompiled_assets_mutex, Mutex.new)
      end

      def self.configure(app)
        precompiled_file = app.assets_config.precompiled
        prev_mtime = ::File.mtime(precompiled_file)

        request_class = app::RodaRequest
        mutex = request_class.instance_variable_get(:@_precompiled_assets_mutex)
        # Unset the assets matchers, in case a frozen value is already set
        request_class.instance_variable_set(:@assets_matchers, nil)
        # Ensure the assets matchers is set and an unfrozen array, and get the underlying value
        request_class.assets_matchers
        assets_matchers = request_class.instance_variable_get(:@assets_matchers)

        app.instance_exec do
          _update_compiled_assets(_compiled_assets_initial_hash.replace(assets_config.compiled))

          define_singleton_method(:recheck_precompiled_assets) do
            new_mtime = ::File.mtime(precompiled_file)
            if new_mtime != prev_mtime
              prev_mtime = new_mtime
              assets_config.compiled.replace(_precompiled_asset_metadata(precompiled_file))

              # Replace the asset matchers, in case the new precompiled metadata uses different files.
              new_assets_matchers = request_class.send(:_build_assets_matchers)
              mutex.synchronize{assets_matchers.replace(new_assets_matchers)}
            end
          end
          singleton_class.send(:alias_method, :recheck_precompiled_assets, :recheck_precompiled_assets)
        end
      end

      module ClassMethods
        private

        # Wrap the precompiled asset metadata in a thread-safe hash.
        def _precompiled_asset_metadata(file)
          CompiledAssetsHash.new.replace(super)
        end

        # Use a thread-safe wrapper of a hash for the :compiled assets option, since
        # the recheck_precompiled_asset_metadata can modify it at runtime.
        def _compiled_assets_initial_hash
          CompiledAssetsHash.new
        end
      end

      module RequestClassMethods
        # Synchronize access and return a dup, so that replacements of the
        # assets matchers at runtime doesn't cause thread safety issues.
        def assets_matchers
          @_precompiled_assets_mutex.synchronize{super.dup}
        end

        private

        # Use a unfrozen array for the assets matchers, so they can be replaced
        # at runtime.
        def _build_assets_matchers
          super.dup
        end

        # Use a regexp that matches any digest.  When the precompiled asset metadata
        # file is updated, this allows requests for a previous precompiled asset to
        # still work.
        def _asset_regexp(type, key, _)
          /#{Regexp.escape(key.sub(/\A#{type}/, ''))}\.[0-9a-fA-F]+\.#{type}/
        end
      end
    end

    register_plugin(:recheck_precompiled_assets, RecheckPrecompiledAssets)
  end
end
