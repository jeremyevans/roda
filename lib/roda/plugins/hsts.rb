# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The hsts plugin configures a Strict-Transport-Security response header
    # for the application:
    #
    #   plugin :hsts
    #   # Strict-Transport-Security: max-age=63072000; includeSubDomains
    #
    #   plugin :hsts, preload: true
    #   # Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
    #
    #   plugin :hsts, max_age: 31536000, subdomains: false
    #   # Strict-Transport-Security: max-age=31536000
    module Hsts
      # Ensure default_headers plugin is loaded first
      def self.load_dependencies(app, opts=OPTS)
        app.plugin :default_headers
      end

      # Configure the Strict-Transport-Security header. Keyword arguments:
      # +max_age+ :: Set max-age in seconds (default is 63072000, two years)
      # +preload+ :: Set preload, so the domain can be included in HSTS preload lists
      # +subdomains+ :: Set to +false+ to not set includeSubDomains. By default, 
      #                 includeSubDomains is set to enforce HTTPS for subdomains.
      def self.configure(app, opts=(no_positional_opts = true; OPTS),
          max_age: opts[:max_age]||63072000,
          subdomains: opts.fetch(:subdomains, true),
          preload: opts[:preload],
          **kw)
        RodaPlugins.check_keywords("the hsts plugin", no_positional_opts, opts, kw)
        app.plugin :default_headers, RodaResponseHeaders::STRICT_TRANSPORT_SECURITY => "max-age=#{max_age}#{'; includeSubDomains' unless subdomains == false}#{'; preload' if preload}".freeze
      end
    end

    register_plugin(:hsts, Hsts)
  end
end
