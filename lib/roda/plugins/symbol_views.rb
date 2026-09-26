# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The symbol_views plugin allows match blocks to return
    # symbols, and consider those symbols as views to use for the
    # response body.  So you can take code like:
    #
    #   r.root do
    #     view :index
    #   end
    #   r.is "foo" do
    #     view :foo
    #   end
    #
    # and DRY it up:
    #
    #   r.root do
    #     :index
    #   end
    #   r.is "foo" do
    #     :foo
    #   end
    module SymbolViews
      def self.load_dependencies(app)
        app.plugin :custom_block_results
      end

      def self.configure(app)
        app.custom_block_results[Symbol] = :view
      end
    end

    register_plugin(:symbol_views, SymbolViews)
  end
end
