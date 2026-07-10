# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The content_for plugin is designed to be used with the
    # render plugin, allowing you to store content inside one
    # template, and retrieve that content inside a separate
    # template.  Most commonly, this is so view templates
    # can set content for the layout template to display outside
    # of the normal content pane.
    #
    # In the template in which you want to store content, call
    # content_for with a block:
    #
    #   <% content_for :foo do %>
    #     Some content here.
    #   <% end %>
    #
    # or:
    #
    #   <% content_for :foo do "Some content here." end %>
    #
    # You can also set the raw content as the second argument,
    # instead of passing a block:
    #
    #   <% content_for :foo, "Some content" %>
    #
    # In the template in which you want to retrieve content,
    # call content_for without the block or argument:
    #
    #   <%= content_for :foo %>
    #
    # Note that when storing content by calling content_for
    # with a block and embedding template code, the return
    # value of the block is used as the content (after being
    # converted to a string).  This can cause issues in some
    # cases, such as:
    #
    #   <% content_for :foo do %>
    #     <% [1,2,3].each do |i| %>
    #       Content <%= i %>
    #     <% end %>
    #   <% end %>
    #
    # In the above example, the return value of the block is
    # <tt>[1,2,3]</tt>, as Array#each returns the receiver.
    # If whitespace is not important, you can work around this by
    # adding an empty line before the end of the content_for block.
    #
    # If content_for is used multiple times with the same key,
    # by default, the last call will append previous calls.
    # If you want to overwrite the previous content, pass the
    # <tt>append: false</tt> option when loading the plugin:
    #
    #   plugin :content_for, append: false
    module ContentFor
      SCOPE_INSTANCE_VARIABLES = [:@_content_for].freeze

      # Depend on the capture_erb plugin, since it uses capture_erb
      # to capture the content.
      def self.load_dependencies(app, _opts = OPTS)
        app.plugin :capture_erb
      end

      # Configure whether to append or overwrite if content_for
      # is called multiple times with the same key.
      def self.configure(app, opts = OPTS)
        app.opts[:append_content_for] = opts.fetch(:append, true)
      end

      module InstanceMethods
        # If called with a block, store content enclosed by block
        # under the given key.  If called without a block, retrieve
        # stored content with the given key, or return nil if there
        # is no content stored with that key.
        def content_for(key, value=nil, &block)
          append = opts[:append_content_for]

          if block || value
            if block
              value = capture_erb(&block)
            end

            @_content_for ||= {}

            if append
              (@_content_for[key] ||= []) << value
            else
              @_content_for[key] = value
            end
          elsif @_content_for && (value = @_content_for[key])
            if append
              value = value.join
            end

            value
          end
        end
      end
    end

    register_plugin(:content_for, ContentFor)
  end
end
