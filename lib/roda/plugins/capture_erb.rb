# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The capture_erb plugin allows you to capture the content of a block
    # in an ERB template, and return it as a value, instead of
    # injecting the template block into the template output.
    #
    #   <% value = capture_erb do %>
    #     Some content here.
    #   <% end %>
    #
    # +capture_erb+ can be used inside other methods that are called
    # inside templates.  It can be combined with the inject_erb plugin
    # to wrap template blocks with arbitrary output and then inject the
    # wrapped output into the template.
    #
    # If the output buffer object responds to +capture+ and is not
    # an instance of String (e.g. when +erubi/capture_block+ is being
    # used as the template engine), this will call +capture+ on the
    # output buffer object, instead of setting the output buffer object
    # temporarily to a new object.
    #
    # By default, capture_erb returns the value of the block, converted
    # to a string.  However, that can cause issues with code such as:
    #
    #   <% value = capture_erb do %>
    #     Some content here.
    #     <% if something %>
    #       Some more content here.
    #     <% end %>
    #   <% end %>
    #
    # In this case, the block may return nil, instead of the content of
    # the template.  To handle this case, you can provide the
    # <tt>returns: :buffer</tt> option when calling the method (to handle
    # that specific call, or when loading the plugin (to default to that
    # behavior). Note that if the output buffer object responds to
    # +capture+ and is not an instance of String, the <tt>returns: :buffer</tt>
    # behavior is the default and cannot be changed.
    module CaptureERB
      def self.load_dependencies(app, opts=OPTS)
        app.plugin :render
      end

      # Support <tt>returns: :buffer</tt> to default to returning buffer
      # object.
      def self.configure(app, opts=OPTS)
        # RODA4: make returns: :buffer the default behavior
        app.opts[:capture_erb_returns] = opts[:returns] if opts.has_key?(:returns)
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :capture_erb_returns)
      end

      module InstanceMethods
        # Temporarily replace the ERB output buffer
        # with an empty string, and then yield to the block.
        # Return the value of the block, converted to a string.
        # Restore the previous ERB output buffer before returning.
        #
        # Options:
        # :returns :: If set to :buffer, returns the value of the
        #             template output variable, instead of the return
        #             value of the block converted to a string. This
        #             is the default behavior if the template output
        #             variable supports the +capture+ method and is not
        #             a String instance.
        def capture_erb(opts=OPTS, &block)
          outvar = render_opts[:template_opts][:outvar]
          buf_was = instance_variable_get(outvar)

          if buf_was.respond_to?(:capture) && !buf_was.instance_of?(String)
            buf_was.capture(&block)
          else
            returns = opts.fetch(:returns) { self.class.capture_erb_returns }

            begin
              instance_variable_set(outvar, String.new)
              if returns == :buffer
                yield
                instance_variable_get(outvar).to_s
              else
                yield.to_s
              end
            ensure
              instance_variable_set(outvar, buf_was) if outvar && buf_was
            end
          end
        end
      end
    end

    register_plugin(:capture_erb, CaptureERB)
  end
end
