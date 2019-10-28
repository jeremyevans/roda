# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The streaming plugin adds support for streaming responses
    # from roda using the +stream+ method:
    #
    #   plugin :streaming
    #
    #   route do |r|
    #     stream do |out|
    #       ['a', 'b', 'c'].each{|v| out << v; sleep 1}
    #     end
    #   end
    #
    # In order for streaming to work, any webservers used in
    # front of the roda app must not buffer responses.
    #
    # The stream method takes the following options:
    #
    # :callback :: A callback proc to call when the connection is closed.
    # :loop :: Whether to call the stream block continuously until the connection is closed.
    # :async :: Whether to call the stream block in a separate thread (default: false).
    # :queue :: A queue object to use for asynchronous streaming (default: `SizedQueue.new(10)`).
    #
    # If the :loop option is used, you can override the
    # handle_stream_error method to change how exceptions
    # are handled during streaming. This method is passed the
    # exception and the stream.  By default, this method
    # just reraises the exception, but you can choose to output
    # the an error message to the stream, before raising:
    #
    #   def handle_stream_error(e, out)
    #     out << 'ERROR!'
    #     raise e
    #   end
    #
    # Ignore errors completely while streaming:
    #
    #   def handle_stream_error(e, out)
    #   end
    #
    # or handle the errors in some other way.
    module Streaming
      # Class of the response body in case you use #stream.
      class Stream
        include Enumerable

        # Handle streaming options, see Streaming for details.
        def initialize(opts=OPTS, &block)
          @block = block
          @out = nil
          @callback = opts[:callback]
          @closed = false
        end

        # Add output to the streaming response body. Returns number of bytes written.
        def write(data)
          data = data.to_s
          @out.call(data)
          data.bytesize
        end

        # Add output to the streaming response body. Returns self.
        def <<(data)
          write(data)
          self
        end

        # If not already closed, close the connection, and call
        # any callbacks.
        def close
          return if closed?
          @closed = true
          @callback.call if @callback
        end

        # Whether the connection has already been closed.
        def closed?
          @closed
        end

        # Yield values to the block as they are passed in via #<<.
        def each(&out)
          @out = out
          @block.call(self)
        ensure
          close
        end
      end

      # Class of the response body if you use #stream with :async set to true.
      class AsyncStream
        include Enumerable

        def initialize(opts=OPTS, &block)
          @stream = Stream.new(opts, &block)
          @queue = fetch_queue(opts)
          @thread = Thread.new { enqueue_chunks }
        end

        def each(&out)
          dequeue_chunks(&out)
          @thread.join
        end

        def close
          @queue.close # terminate the producer thread
          @stream.close
        end

        private

        def enqueue_chunks
          @stream.each do |chunk|
            @queue.push(chunk)
          end
        rescue ClosedQueueError
          # connection was closed
        ensure
          @queue.close
        end

        def dequeue_chunks
          loop do
            chunk = @queue.pop

            if chunk
              yield chunk
            else
              break
            end
          end
        end

        if RUBY_VERSION >= '2.3'
          # Returns queue to be used for sending chunks.
          def fetch_queue(opts)
            opts[:queue] || SizedQueue.new(10)
          end
        else
          # :nocov:
          def fetch_queue(opts)
            ClosableQueue.new(opts[:queue] || SizedQueue.new(10))
          end

          # Queue wrapper that implements #close for Rubies lower than 2.3.0.
          class ClosableQueue
            def initialize(queue)
              @queue = queue
              @closed = false
            end

            def push(chunk)
              raise ClosedQueueError, "queue closed" if @closed
              @queue.push(chunk)
            end

            def pop
              @queue.pop
            end

            def close
              @closed = true
              @queue.push(nil)
            end
          end

          class ClosedQueueError < StopIteration; end
          # :nocov:
        end
      end

      module InstanceMethods
        # Immediately return a streaming response using the current response
        # status and headers, calling the block to get the streaming response.
        # See Streaming for details.
        def stream(opts=OPTS, &block)
          if opts[:loop]
            block = proc do |out|
              until out.closed?
                begin
                  yield(out)
                rescue => e
                  handle_stream_error(e, out)
                end
              end
            end
          end

          stream_class = opts[:async] ? AsyncStream : Stream

          throw :halt, @_response.finish_with_body(stream_class.new(opts, &block))
        end

        # Handle exceptions raised while streaming when using :loop
        def handle_stream_error(e, out)
          raise e
        end
      end
    end

    register_plugin(:streaming, Streaming)
  end
end
