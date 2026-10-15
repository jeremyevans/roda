# frozen-string-literal: true

class Roda
  # A thread safe cache class, offering only #[] and #[]= methods,
  # each protected by a mutex.
  class RodaCache
    # Create a new thread safe cache.
    def initialize
      @mutex = Mutex.new
      @hash = {}
    end

    # Make getting value from underlying hash thread safe.
    def [](key)
      @mutex.synchronize{@hash[key]}
    end

    # Make setting value in underlying hash thread safe.
    def []=(key, value)
      @mutex.synchronize{@hash[key] = value}
    end

    # Return the frozen internal hash.  The internal hash can then
    # be accessed directly since it is frozen and there are no
    # thread safety issues.
    def freeze
      @hash.freeze
    end

    private

    # Create a copy of the cache with a separate mutex.
    def initialize_copy(other)
      @mutex = Mutex.new
      other.instance_variable_get(:@mutex).synchronize do
        @hash = other.instance_variable_get(:@hash).dup
      end
    end
  end
end
