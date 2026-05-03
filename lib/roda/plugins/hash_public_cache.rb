# frozen-string-literal: true

require 'json'
require 'find'

class Roda
  module RodaPlugins
    # The hash_public_cache plugin builds on top of the hash_public plugin and
    # adds the ability to store the digests for the public files in a json file,
    # and load that file at startup, which avoids the need for the process to
    # read the public file in order to compute the digest.
    #
    # Examples:
    #
    #   # Load the plugin. Options given will be passed to public and hash_public.
    #   plugin :hash_public_cache, "path/to/cache_file.json"
    #
    #   # When rebuilding the cache:
    #   #
    #   # * Scan the public directory for files, calculate the digest on each.
    #   # * Write the hash public cache to a file.
    #   #
    #   # This is split into separate steps in case you want to modify the cache
    #   # manually after the scan.
    #   scan_hash_public_cache_dir
    #   dump_hash_public_cache_file 
    #
    #   # To load the cache at application startup (if the file exists):
    #   load_hash_public_cache_file
    module HashPublicCache
      def self.load_dependencies(app, _cache_file, opts = OPTS)
        app.plugin :hash_public, opts
      end

      # Specify the location of the hash public cache file.
      #
      # The options given are passed to the hash_public plugin.
      def self.configure(app, cache_file, opts = OPTS)
        app.opts[:hash_public_cache_file] = cache_file
      end

      module ClassMethods
        # Load the hash public cache file, if it exists. This replaces the hash
        # public cache with the values from the file.
        def load_hash_public_cache_file
          file = opts[:hash_public_cache_file]
          return unless File.file?(file)

          cache = opts[:hash_public_cache] = (opts[:json_parser] || ::JSON.method(:parse)).call(::File.read(file))
          cache.each_value(&:freeze)
          nil
        end

        # Scan the public directory for files, computing the hash public digest
        # for each. This will not rescan files that already have digest values.
        # If a block is given, it will only calculate the digest for the file
        # if the block returns truthy.
        def scan_hash_public_cache_dir
          cache = opts[:hash_public_cache]

          # Public root doesn't have trailing slash even if given, as
          # File.expand_path removes it.
          root = opts[:public_root] + File::SEPARATOR

          Find.find(opts[:public_root]) do |file|
            if File.file?(file)
              file = file.sub(root, '')
              next if cache[file]

              if defined?(yield)
                next unless yield file
              end

              cache[file] = hash_path_digest(file)
            end
          end

          nil
        end

        # Write the current hash public cache to the cache file.
        def dump_hash_public_cache_file
          File.write(opts[:hash_public_cache_file], (opts[:json_serializer] || :to_json.to_proc).call(opts[:hash_public_cache]))
          nil
        end
      end
    end

    register_plugin(:hash_public_cache, HashPublicCache)
  end
end
