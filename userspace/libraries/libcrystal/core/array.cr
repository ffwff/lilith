GC_ARRAY_HEADER_TYPE = 0xFFFF_FFFF.to_usize
GC_ARRAY_HEADER_SIZE = sizeof(USize) * 2

class Array(T)
  @capacity : Int32
  getter capacity

  def size
    return 0 if @capacity == 0
    @buffer[1].to_isize
  end

  protected def size=(new_size)
    return if @capacity == 0
    @buffer[1] = new_size.to_usize
  end

  private def malloc_size(new_size)
    new_size.to_usize * sizeof(Void*) + GC_ARRAY_HEADER_SIZE
  end

  private def new_buffer(new_size)
    if old_size > capacity
      abort "size must be smaller than capacity"
    end
    old_size = size
    old_buffer = @buffer
    @buffer = Pointer(USize).malloc malloc_size(new_size)
    old_buffer.copy_to @buffer, malloc_size(old_size)
  end

  def initialize
    @capacity = 0
    @buffer = Pointer(USize).null
  end

  def initialize(initial_capacity)
    @capacity = initial_capacity
    if initial_capacity > 0
      @buffer = Pointer(USize).malloc malloc_size(initial_capacity)
      @buffer[0] = GC_ARRAY_HEADER_TYPE
      @buffer[1] = 0u32
    else
      @buffer = Pointer(USize).null
    end
  end

  def clone
    Array(T).build(size) do |ary|
      size.times do |i|
        ary.to_unsafe[i] = to_unsafe[i]
      end
      size
    end
  end

  def self.build(capacity : Int) : self
    ary = Array(T).new(capacity)
    ary.size = (yield ary.to_unsafe).to_i
    ary
  end

  def self.new(size : Int, &block : Int32 -> T)
    Array(T).build(size) do |buffer|
      size.to_i.times do |i|
        buffer[i] = yield i
      end
      size
    end
  end

  def to_unsafe
    (@buffer + 2).as(T*)
  end

  def [](idx : Int)
    abort "accessing out of bounds!" unless 0 <= idx && idx < size
    to_unsafe[idx]
  end

  def []?(idx : Int) : T?
    return nil unless 0 <= idx && idx <= size
    to_unsafe[idx]
  end

  def []=(idx : Int, value : T)
    abort "setting out of bounds!" unless 0 <= idx && idx < size
    to_unsafe[idx] = value
  end

  def push(value : T)
    if size < capacity
      to_unsafe[size] = value
      self.size += 1
    else
      idx = size
      new_buffer(size + 1)
      to_unsafe[idx] = value
    end
  end

  def each
    i = 0
    while i < size
      yield to_unsafe[i]
      i += 1
    end
  end

  def to_s(io)
    io << "["
    each do |obj|
      io << obj
      io << ", "
    end
    io << "]"
  end
end
