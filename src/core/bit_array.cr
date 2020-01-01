# A bitmap array, see [Crystal's documentation](https://crystal-lang.org/api/0.32.1/BitArray.html) for more detail.
struct BitArray
  @size = 0
  getter size
  @pointer = Pointer(UInt32).null

  def to_unsafe
    @pointer
  end

  def initialize(@pointer : UInt32*, @size : Int32)
  end

  def self.pmalloc(size : Int32)
    new PermaAllocator.malloc(malloc_size(size)).as(UInt32*), size
  end

  def self.null
    new Pointer(UInt32).null, 0
  end

  # methods
  def []=(k : Int, value : Bool)
    abort "pbitarray: out of range" unless 0 <= k < @size
    if value
      @pointer[index_position k] |= 1 << bit_position k
    else
      @pointer[index_position k] &= ~(1 << bit_position k)
    end
  end

  def [](k : Int) : Bool
    abort "pbitarray: out of range" unless 0 <= k < @size
    if (@pointer[index_position k] & (1 << bit_position k)) != 0
      true
    else
      false
    end
  end

  def clear
    memset @pointer.as(UInt8*), 0.to_usize, (malloc_size*4).to_usize
  end

  def first_unset
    malloc_size.times do |i|
      if @pointer[i] != (~0).to_u32
        k = i * 32 + @pointer[i].find_first_zero
        return -1 if k > @size
        return k
      end
    end
    -1
  end

  def first_unset_from(idx : Int32)
    malloc_size.times do |i|
      if @pointer[i] != (~0).to_u32
        k = {i, i * 32 + @pointer[i].find_first_zero}
        return {-1, -1} if k[1] > @size
        return k
      end
    end
    {-1, -1}
  end

  def popcount
    count = 0
    malloc_size.times do |i|
      count += @pointer[i].popcount
    end
    count
  end

  def mask(other : self)
    malloc_size.times do |i|
      @pointer[i] = @pointer[i] & other.to_unsafe[i]
    end
  end

  def each(&block)
    @size.times do |i|
      yield self[i]
    end
  end

  # to_s
  def to_s(io)
    io.print "BitArray ["
    size.times do |i|
      io.print (self[i] ? '1' : '0')
    end
    io.print "]"
  end

  # size
  def self.malloc_size(size : Int32)
    size.div_ceil 32
  end

  private def malloc_size : Int32
    BitArray.malloc_size @size
  end

  # position
  private def index_position(k : Int)
    k // 32
  end

  private def bit_position(k : Int)
    k % 32
  end
end
