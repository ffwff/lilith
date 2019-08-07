module FrameAllocator
  extend self

  struct Region
    @base_addr = 0u64
    @length = 0u64
    getter base_addr, length

    @frames = PBitArray.null

    @search_from = 0

    @next_region = Pointer(Region).null
    property next_region

    def _initialize(@base_addr : UInt64, @length : UInt64)
      nframes = @length.unsafe_div(0x1000).to_i32
      @frames = PBitArray.new nframes
    end

    def to_s(io)
      @base_addr.to_s io, 16
      io.puts ':'
      @length.to_s io, 16
    end

    private def index_for_address(addr : UInt64)
      (addr - @base_addr).unsafe_div(0x1000).to_i32
    end

    def initial_claim(addr : UInt64)
      idx = index_for_address(addr)
      @frames[idx] = true
    end

    def claim
      idx, iaddr = @frames.first_unset_from @search_from
      @search_from = max idx, @search_from
      return nil if iaddr == -1
      @frames[iaddr] = true
      iaddr
    end

    def claim_with_addr
      if (iaddr = claim).nil?
        return
      end
      iaddr = iaddr.not_nil!
      addr = iaddr.to_u32 * 0x1000 + @base_addr
      Tuple.new(iaddr, addr)
    end

    def declaim_addr(addr : UInt64)
      unless addr > @base_addr && addr < (@base_addr + @length)
        return false
      end
      idx = index_for_address(addr)
      @search_from = min idx, @search_from
      @frames[idx] = false
      true
    end
  end

  @@first_region = Pointer(Region).null
  @@last_region = Pointer(Region).null

  def add_region(base_addr : UInt64, length : UInt64)
    region = Pointer(Region).pmalloc
    region.value._initialize(base_addr, length)
    if @@first_region.null?
      @@first_region = region
      @@last_region = region
    else
      @@last_region.value.next_region = region
      @@last_region = region
    end
  end

  def each_region(&block)
    region = @@first_region
    while !region.null?
      yield region.value
      region = region.value.next_region
    end
  end

  def initial_claim(addr : UInt64)
    @@first_region.value.initial_claim addr
  end

  def claim
    each_region do |region|
      if !(frame = region.claim).nil?
        return frame
      end
    end
    panic "no more physical memory!"
    0
  end

  def declaim_addr(addr : UInt64)
    each_region do |region|
      if region.declaim_addr addr
        return true
      end
    end
    false
  end

  def claim_with_addr
    each_region do |region|
      if !(frame = region.claim_with_addr).nil?
        return frame
      end
    end
    panic "no more physical memory!"
    Tuple.new(0, 0u32)
  end

end