require "./enumerable.cr"
require "./indexable.cr"

GC_ARRAY_HEADER_TYPE = 0xFFFF_FFFF.to_usize
GC_ARRAY_HEADER_SIZE = sizeof(USize) * 2

class Array(T)
  include Enumerable(T)
  include Indexable(T)

  @capacity : Int32
  getter capacity

  def size
    return 0 if @capacity == 0
    @buffer[1].to_i32
  end

  protected def size=(new_size)
    return if @capacity == 0
    @buffer[1] = new_size.to_usize
  end

  private def malloc_size(new_size)
    new_size.to_usize * sizeof(T) + GC_ARRAY_HEADER_SIZE
  end

  private def capacity_for_ptr(ptr)
    ((Allocator.block_size_for_ptr(ptr) - GC_ARRAY_HEADER_SIZE) // sizeof(T)).to_i32
  end

  private def new_buffer(new_capacity)
    if size > capacity
      abort "size must be smaller than capacity"
    elsif new_capacity <= @capacity
      return
    end
    if @buffer.null?
      {% if T < Int %}
        @buffer = Gc.unsafe_malloc(malloc_size(new_capacity), true).as(USize*)
      {% else %}
        @buffer = Gc.unsafe_malloc(malloc_size(new_capacity)).as(USize*)
      {% end %}
      @buffer[0] = GC_ARRAY_HEADER_TYPE
      @buffer[1] = 0u32
    else
      @buffer = Gc.realloc(@buffer.as(Void*), malloc_size(new_capacity)).as(USize*)
    end
    @capacity = capacity_for_ptr @buffer
  end

  def initialize
    @capacity = 0
    @buffer = Pointer(USize).null
  end

  def initialize(initial_capacity)
    if initial_capacity > 0
      {% if T < Int %}
        @buffer = Gc.unsafe_malloc(malloc_size(initial_capacity), true).as(USize*)
      {% else %}
        @buffer = Gc.unsafe_malloc(malloc_size(initial_capacity)).as(USize*)
      {% end %}
      @capacity = capacity_for_ptr @buffer
      @buffer[0] = GC_ARRAY_HEADER_TYPE
      @buffer[1] = 0u32
    else
      @buffer = Pointer(USize).null
      @capacity = 0
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
    # set the array's size to capacity beforehand
    # so when the array is scanned by the gc, its values won't be deleted
    # before the actual size is set
    LibC.memset(ary.to_unsafe, 0, sizeof(T) * capacity)
    ary.size = capacity
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

  def to_slice
    Slice(T).new(to_unsafe, size)
  end

  def sort!
    to_slice.sort!
  end

  def [](idx : Int)
    abort "accessing out of bounds!" unless 0 <= idx < size
    to_unsafe[idx]
  end

  def []?(idx : Int) : T?
    return nil unless 0 <= idx < size
    to_unsafe[idx]
  end

  def []=(idx : Int, value : T)
    abort "setting out of bounds!" unless 0 <= idx < size
    to_unsafe[idx] = value
  end

  def push(value : T)
    if size < capacity
      to_unsafe[size] = value
    else
      new_buffer(size + 1)
      to_unsafe[size] = value
    end
    self.size = self.size + 1
  end

  def shift
    return nil if size == 0
    retval = to_unsafe[0]
    LibC.memmove(to_unsafe,
      to_unsafe + 1,
      sizeof(T) * (self.size - 1))
    self.size = self.size - 1
    retval
  end

  def pop
    return nil if size == 0
    retval = to_unsafe[self.size - 1]
    self.size = self.size - 1
    retval
  end

  def delete(obj)
    i = 0
    size = self.size
    while i < size
      if to_unsafe[i] == obj
        LibC.memmove(to_unsafe + i, to_unsafe + i + 1,
          sizeof(T) * (size - i - 1))
        size -= 1
      else
        i += 1
      end
    end
  end

  def delete_at(idx : Int)
    return false unless 0 <= idx && idx < size
    if idx == size - 1
      self.size = self.size - 1
    else
      LibC.memmove(to_unsafe + idx, to_unsafe + idx + 1,
        sizeof(T) * (size - idx - 1))
    end
    true
  end

  def clear
    self.size = 0
  end

  def each
    i = 0
    while i < size
      yield to_unsafe[i]
      i += 1
    end
  end

  def reverse_each
    i = size - 1
    while i >= 0
      yield to_unsafe[i]
      i -= 1
    end
  end

  def to_s(io)
    io << "["
    i = 0
    while i < size - 1
      io << self[i] << ", "
      i += 1
    end
    if size > 0
      io << self[size - 1]
    end
    io << "]"
  end
end
