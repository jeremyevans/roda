# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The each_part plugin adds an each_part method, which is a
    # render_each-like method that treats all keywords as locals.
    #
    #   # Can replace this:
    #   render_each(enum, :template, locals: {foo: 'bar'})
    #
    #   # With this:
    #   each_part(enum, :template, foo: 'bar')
    #
    # On Ruby 2.7+, the part method takes a keyword splat, so you
    # must pass keywords and not a positional hash for the locals.
    #
    # If you are using the :assume_fixed_locals render plugin option,
    # template caching is enabled, you are using Ruby 3+, and you
    # are freezing your Roda application, in addition to providing a
    # simpler API, this also provides a performance improvement.
    module EachPart
      def self.load_dependencies(app)
        app.plugin :render_each
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
            def each_part(enum, template, **locals, &block)
              render_each(enum, template, :locals=>locals, &block)
            end
          RUBY
        # simplecov:disable
        else
          def each_part(enum, template, locals=OPTS, &block)
            render_each(enum, template, :locals=>locals, &block)
          end
        end
        # simplecov:enable
      end

      module AssumeFixedLocalsInstanceMethods
        # simplecov:disable
        if RUBY_VERSION >= '3.0'
        # simplecov:enable
          class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
            def each_part(enum, template, **locals, &block)
              if optimized_method = _cached_render_each_template_method(template)
                optimized_method = optimized_method[0]
                as = render_each_default_local(template)
                if defined?(yield)
                  enum.each do |v|
                    locals[as] = v
                    yield send(optimized_method, **locals)
                  end
                  nil
                else
                  enum.map do |v|
                    locals[as] = v
                    send(optimized_method, **locals)
                  end.join
                end
              else
                render_each(enum, template, :locals=>locals, &block)
              end
            end
          RUBY
        end
      end
    end

    register_plugin(:each_part, EachPart)
  end
end
