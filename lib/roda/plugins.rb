# frozen-string-literal: true

require_relative "cache"

class Roda
  # Module in which all Roda plugins should be stored. Also contains logic for
  # registering and loading plugins.
  module RodaPlugins
    NOOP = ->(*args) { args }.freeze
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
  end
end
