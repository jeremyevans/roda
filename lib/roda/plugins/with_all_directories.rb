# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The with_all_directories plugin matches all directories in an URL and returns them to it's block.
    # The directory part is returned without starting nor ending slashes. As directories are considered only items ending with a slash,
    # so "/food/vegetables/" would match both items, but "/food/vegetables" would match only the food.
    # The method always matches (returns empty string in the root), therefore the execution will stop at the end of the block, unless there is something else matching inside.
    #
    # Example:
    #
    #   r.with_all_directories do |category|
    #
    #     r.is '' do
    #       # will match URL "/food/vegetables/"
    #       # the category will be equal to "food/vegetables"
    #       # now you can display a list of the category, for instance
    #     end
    #
    #     r.is String do |item|
    #       # will match URL "/food/vegetables/potatoes.html"
    #       # the category will equal to "food/vegetables"
    #       # now you can show the item (potatoes.html)
    #     end
    #
    #   end
    #
    module WithAllDirectories
      module RequestMethods

        def with_all_directories
          if remaining_path.empty?
            block_result(yield(''))
          else
            matchdata = remaining_path.match(/\A(\/(.*))?(?=\/[^\/]*\z)/)
            @remaining_path = matchdata.post_match
            block_result(yield(matchdata.captures[1].to_s))
          end
          throw :halt, response.finish
        end

      end
    end

    register_plugin(:with_all_directories, WithAllDirectories)
  end
end
