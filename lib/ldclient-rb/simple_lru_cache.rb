
module LaunchDarkly
  # A non-thread-safe implementation of a LRU cache set with only add and reset methods.
  # Based on https://github.com/SamSaffron/lru_redux/blob/master/lib/lru_redux/cache.rb
  class SimpleLRUCacheSet
    def initialize(capacity)
      @values = {}
      @capacity = capacity
    end

    # Adds a value to the cache or marks it recent if it was already there. Returns true if already there.
    def add(value)
      found = true
      @values.delete(value) { found = false }
      @values[value] = true
      @values.shift if @values.length > @capacity
      found
    end

    def clear
      @values = {}
    end
  end
end
