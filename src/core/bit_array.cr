struct BitArray
  @size = 0
  getter size
  @pointer = Pointer(UInt32).null

  def to_unsafe
    @pointer
  end

  def initialize(@pointer : UInt32*, @size : Int32)
  end

  def initialize(@size : Int32)
    @pointer = Pointer(UInt32).pmalloc malloc_size
  end

  def self.null
    new 0, Pointer(UInt32).null
  end

  def initialize(@size, @pointer)
  end

  # methods
  def []=(k : Int, value : Bool)
    panic "pbitarray: out of range" if k > size || k < 0
    if value
      @pointer[index_position k] |= 1 << bit_position k
    else
      @pointer[index_position k] &= ~(1 << bit_position k)
    end
  end

  def [](k : Int) : Bool
    panic "pbitarray: out of range" if k > size || k < 0
    if (@pointer[index_position k] & (1 << bit_position k)) != 0
      true
    else
      false
    end
  end

  def first_unset
    i = 0
    while i < malloc_size
      if @pointer[i] != (~0).to_u32
        return i * 32 + @pointer[i].ffz
      end
      i += 1
    end
    -1
  end

  def first_unset_from(idx : Int32)
    i = idx
    while i < malloc_size
      if @pointer[i] != (~0).to_u32
        return {i, i * 32 + @pointer[i].find_first_zero}
      end
      i += 1
    end
    {-1, -1}
  end

  # TODO: find a better algorithm
  def first_unset_bits(n : Int)
    panic "unsupported" if n > 8
    max_words = 1
    i = 0
    while i < malloc_size
      first_idx = i * 32 + @pointer[i].ffz
      next_idx = begin
        j = i
        while j < malloc_size
          if @pointer[i] == 0
            return 1
          end
          j += 1
        end
      end
      i += 1
    end
    -1
  end

  # to_s
  def to_s(io)
    io.print "PBitArray ["
    size.times do |i|
      io.print (self[i] ? '1' : '0')
    end
    io.print "]"
  end

  # size
  private def malloc_size : Int32
    @size.div_ceil 32
  end

  # position
  private def index_position(k : Int)
    k // 32
  end

  private def bit_position(k : Int)
    k % 32
  end
end
