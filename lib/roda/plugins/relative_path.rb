# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The relative_path plugin adds a relative_path method that accepts
    # an absolute path and returns a path relative to the current request
    # by adding an appropriate prefix:
    #
    #   plugin :relative_path
    #   route do |r|
    #     relative_path("/foo")
    #   end
    #
    #   # GET /
    #   "./foo"
    #
    #   # GET /bar
    #   "./foo"
    #
    #   # GET /bar/
    #   "../foo"
    #
    #   # GET /bar/baz/quux
    #   "../../foo"
    #
    # It also offers a relative_prefix method that returns a string that can
    # be prepended to an absolute path.  This can be more efficient if you
    # need to convert multiple paths.
    #
    # This plugin is mostly designed for applications using Roda as a static
    # site generator, where the generated site can be hosted at any subpath.
    module RelativePath
      SCOPE_INSTANCE_VARIABLES = [:@_relative_prefix].freeze

      module InstanceMethods
        # Return a relative path for the absolute path based on the current path
        # of the request by adding the appropriate prefix.
        def relative_path(absolute_path)
          relative_prefix + absolute_path
        end

        # Return a relative prefix to append to an absolute path to a relative path
        # based on the current path of the request.
        def relative_prefix
          return @_relative_prefix if @_relative_prefix
          env = @_request.env
          script_name = env["SCRIPT_NAME"]
          path_info = env["PATH_INFO"]

          # Check path begins with slash.  All valid paths should, but in case this
          # request is bad, just skip using a relative prefix.
          case script_name.getbyte(0)
          when nil # SCRIPT_NAME empty
            unless path_info.getbyte(0) == 47 # PATH_INFO starts with /
              return(@_relative_prefix = '')
            end
          when 47 # SCRIPT_NAME starts with /
            # nothing
          else
            return(@_relative_prefix = '')
          end

          slash_count = script_name.count('/') + path_info.count('/')
          @_relative_prefix = if slash_count > 1
            ("../" * (slash_count - 2)) << ".."
          else
            "."
          end
        end
      end
    end

    register_plugin(:relative_path, RelativePath)
  end
end
