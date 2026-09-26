# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The custom_block_results plugin allows you to specify handling
    # for different block results.  By default, Roda only supports
    # nil, false, and string block results, but using this plugin,
    # you can support other block results.
    #
    # For example, if you wanted to support returning Integer
    # block results, and have them set the response status code,
    # you could do:
    #
    #   plugin :custom_block_results
    #
    #   handle_block_result Integer do |result|
    #     response.status_code = result
    #   end
    #
    #   route do |r|
    #     200
    #   end
    #
    # The expected use case for this is to customize behavior by
    # class, but matching uses ===, so it is possible to use non-class
    # objects that respond to === appropriately.
    #
    # Note that custom block result handling only occurs if the types
    # are not handled by Roda itself.  You cannot use this to modify
    # the handling of nil, false, or string results.  Additionally,
    # if the response body has already been written to before the the
    # route block exits, then the result of the block is ignored,
    # and the related +handle_block_result+ block will not be called
    # (this is standard Roda behavior).
    # 
    # The return value of the +handle_block_result+ block is written
    # to the body if the block return value is a String, similar to
    # standard Roda handling of block results.  Non-String return
    # values are ignored.
    module CustomBlockResults
      def self.configure(app)
        app.opts[:custom_block_results] ||= {}
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :custom_block_results)

        # Freeze the configured custom block results when freezing the app.
        def freeze
          custom_block_results.freeze
          super
        end

        # Specify a block that will be called when an instance of klass
        # is returned as a block result.  The block defines a method.
        def handle_block_result(klass, &block)
          custom_block_results[klass] = define_roda_method(custom_block_results[klass] || "custom_block_result_#{klass}", 1, &block)
        end
      end

      module RequestMethods
        private

        # Try each configured custom block result, and call the related method
        # to get the block result.
        def unsupported_block_result(result)
          roda_class.custom_block_results.each do |klass, meth|
            if klass === result
              result = scope.send(meth, result)

              if String === result
                return result
              else
                return
              end
            end
          end

          super
        end
      end
    end

    register_plugin(:custom_block_results, CustomBlockResults)
  end
end
