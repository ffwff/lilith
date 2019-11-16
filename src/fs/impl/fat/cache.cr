module FatCache

  struct CacheNode
    getter foffset, cluster, used
    protected setter used
    def initialize(@foffset : UInt32, @cluster : UInt32, @used : Int32)
    end
  end

  MAX_CACHE_SIZE = 8
  @cache : Slice(CacheNode)? = nil
  private getter! cache

  def init_cache
    return unless @cache.nil?
    @cache = Slice(CacheNode).malloc_atomic MAX_CACHE_SIZE
    MAX_CACHE_SIZE.times do |i|
      cache[i] = CacheNode.new 0, 0, 0
    end
  end

  def insert_cache(foffset : UInt32, cluster : UInt32)
    min_idx, min_val = 0, 0
    idx = 0
    while idx < cache.size
      if cache[idx].foffset == foffset
        cache[idx].used += 1
        return
      end
      if cache[idx].used < min_val
        min_idx = idx
        min_val = cache[idx].used
      end
      idx += 1
    end
    # Serial.print "insert cache: ", foffset, " => ", cluster, '\n'
    cache[min_idx] = CacheNode.new(foffset, cluster, 1)
  end

  def get_cache(foffset) : UInt32?
    MAX_CACHE_SIZE.times do |i|
      if cache[i].used != 0 && cache[i].foffset == foffset
        # Serial.print "cache hit: ", foffset, " => ", cache[i].cluster, "!\n"
        cache[i].used += 1
        return cache[i].cluster
      end
      i += 1
    end
  end

end
