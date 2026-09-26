# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The match_hook_args plugin adds hooks that are called upon a successful match
    # by any of the matchers. It is similar to the match_hook plugin, but it allows
    # for passing the matchers and block arguments for each match method.
    #
    #   plugin :match_hook_args
    #
    #   add_match_hook do |matchers, block_args|
    #     logger.debug("matchers: #{matchers.inspect}. #{block_args.inspect} yielded.")
    #   end
    #
    #   # Term is an implicit matcher used for terminating matches, and
    #   # will be included in the array of matchers yielded to the match hook 
    #   # if a terminating match is used.
    #   term = self.class::RodaRequest::TERM
    #
    #   route do |r|
    #     r.root do
    #       # for a request for /
    #       # matchers: nil, block_args: nil
    #     end
    #
    #     r.on 'a', ['b', 'c'], Integer do |segment, id|
    #       # for a request for /a/b/1
    #       # matchers: ["a", ["b", "c"], Integer], block_args: ["b", 1]
    #     end
    #
    #     r.get 'd' do
    #       # for a request for /d
    #       # matchers: ["d", term], block_args: []
    #     end
    #   end
    module MatchHookArgs
      def self.configure(app)
        app.opts[:match_hook_args] ||= []
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :match_hook_args)

        # Freeze the array of hook methods when freezing the app
        def freeze
          match_hook_args.freeze
          super
        end

        # Add a match hook that will be called with matchers and block args.
        def add_match_hook(&block)
          match_hook_args << define_roda_method("match_hook_args", :any, &block)

          if match_hook_args.length == 1
            class_eval("alias _match_hook_args #{match_hook_args.first}", __FILE__, __LINE__)
          else
            class_eval("def _match_hook_args(v, a); #{match_hook_args.map{|m| "#{m}(v, a)"}.join(';')} end", __FILE__, __LINE__)
          end

          public :_match_hook_args

          nil
        end
      end

      module InstanceMethods
        # Default empty method if no match hooks are defined.
        def _match_hook_args(matchers, block_args)
        end
      end

      module RequestMethods
        private

        # Call the match hook with matchers and block args if yielding to the block before yielding to the block.
        def if_match(v)
          super do |*a|
            scope._match_hook_args(v, a)
            yield(*a)
          end
        end

        # Call the match hook with nil matchers and blocks before yielding to the block
        def always
          scope._match_hook_args(nil, nil)
          super
        end
      end
    end

    register_plugin :match_hook_args, MatchHookArgs
  end
end

