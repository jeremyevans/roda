# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The run_require_slash plugin makes +r.run+ a no-op if the remaining
    # path is not empty and does not start with +/+. The Rack SPEC requires that
    # +PATH_INFO+ start with a slash if not empty, so this plugin prevents
    # dispatching to the application with an environment that would violate the
    # Rack SPEC.
    #
    # You are unlikely to want to use this plugin unless when consuming partial
    # segments of the request path, or using the match_affix plugin to change
    # how routing is done:
    #
    #   plugin :match_affix, "", /(\/|\z)/
    #   route do |r|
    #     r.on "/a" do
    #       r.on "b" do
    #         r.run App
    #       end
    #     end
    #   end
    #
    #   # with run_require_slash: 
    #   # GET /a/b/e => App not dispatched to application
    #   # GET /a/b => App gets "" as PATH_INFO
    #
    #   # without run_require_slash: 
    #   # GET /a/b/e => App gets "e" as PATH_INFO, violating rack SPEC
    #   # GET /a/b => App gets "" as PATH_INFO
    module RunRequireSlash
      module RequestMethods
        # Calls the given rack app only if the remaining patch is empty or
        # starts with a slash.
        def run(*)
          if @remaining_path.empty? || @remaining_path.start_with?('/')
            super
          end
        end
      end
    end

    register_plugin(:run_require_slash, RunRequireSlash)
  end
end
