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
        unless app.respond_to?(:assets_opts) && app.assets_opts[:precompiled]
          raise RodaError, "must load assets plugin with precompiled option before loading recheck_precompiled_assets plugin"
        end
      end

      def self.configure(app)
        precompiled_file = app.assets_opts[:precompiled]
        prev_mtime = ::File.mtime(precompiled_file)
        app.instance_exec do
          opts[:assets] = assets_opts.merge(:compiled=>_compiled_assets_initial_hash.replace(assets_opts[:compiled])).freeze

          define_singleton_method(:recheck_precompiled_assets) do
            new_mtime = ::File.mtime(precompiled_file)
            if new_mtime != prev_mtime
              prev_mtime = new_mtime
              assets_opts[:compiled].replace(_precompiled_asset_metadata(precompiled_file))

              # Unset the cached asset matchers, so new ones will be generated.
              # This is needed in case the new precompiled metadata uses
              # different files.
              app::RodaRequest.instance_variable_set(:@assets_matchers, nil)
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
        private

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
