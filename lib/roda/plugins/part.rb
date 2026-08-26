# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The part plugin adds a part method, which is a
    # render-like method that treats all keywords as locals.
    #
    #   # Can replace this:
    #   render(:template, locals: {foo: 'bar'})
    #
    #   # With this:
    #   part(:template, foo: 'bar')
    #
    # On Ruby 2.7+, the part method takes a keyword splat, so you
    # must pass keywords and not a positional hash for the locals.
    #
    # If you are using the :assume_fixed_locals render plugin option,
    # template caching is enabled, you are using Ruby 3+, and you
    # are freezing your Roda application, in addition to providing a
    # simpler API, this also provides a significant performance
    # improvement (more significant on Ruby 3.4+).
    module Part
      def self.load_dependencies(app)
        app.plugin :render
      end

      module ClassMethods
        # When freezing, optimize the part method if assuming fixed locals
        # and caching templates.
        def freeze
          if render_opts[:assume_fixed_locals] && !render_opts[:check_template_mtime]
            include AssumeFixedLocalsInstanceMethods
          end

          super
        end
      end

      module InstanceMethods
        if RUBY_VERSION >= '2.7'
          class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
            def part(template, **locals, &block)
              render(template, :locals=>locals, &block)
            end
          RUBY
        # simplecov:disable
        else
          def part(template, locals=OPTS, &block)
            render(template, :locals=>locals, &block)
          end
        end
        # simplecov:enable
      end

      module AssumeFixedLocalsInstanceMethods
        # simplecov:disable
        if RUBY_VERSION >= '3.0'
        # simplecov:enable
          class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
            def part(template, ...)
              if optimized_method = _optimized_render_method_for_locals(template, OPTS)
                send(optimized_method[0], ...)
              else
                super
              end
            end
          RUBY
        end
      end
    end

    register_plugin(:part, Part)
  end
end

