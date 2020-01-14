# A simple dynamic array, see [Crystal's documentation](https://crystal-lang.org/api/0.32.1/Array.html) for more detail.
class Array(T) < Markable
  @size = 0
  @capacity = 0
  getter size, capacity
  protected setter size

  @buffer : T* = Pointer(T).null

  def to_unsafe
    @buffer
  end

  private def recalculate_capacity
    @capacity = Allocator.block_size_for_ptr(@buffer) // sizeof(T)
  end

  private def expand(new_capacity)
    if @size > new_capacity
      abort "size must be smaller than capacity"
    end
    if @buffer.null?
      @buffer = Pointer(T).malloc_atomic(new_capacity)
    else
      @buffer = @buffer.realloc(new_capacity.to_u64)
    end
    recalculate_capacity
  end

  def initialize(initial_capacity : Int = 0)
    if initial_capacity > 0
      @buffer = Pointer(T).malloc_atomic(initial_capacity.to_u64)
      recalculate_capacity
    end
  end

  def self.build(capacity : Int) : self
    ary = Array(T).new(capacity)
    ary.write_barrier do
      ary.size = (yield ary.to_unsafe).to_i
    end
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

  def each(&block)
    @size.times do |i|
      yield @buffer[i]
    end
  end

  def each_with_index(&block)
    @size.times do |i|
      yield @buffer[i], i
    end
  end

  def reverse_each
    i = size - 1
    while i >= 0
      yield @buffer[i]
      i -= 1
    end
  end

  def clone
    Array(T).build(size) do |buffer|
      size.times do |i|
        buffer[i] = to_unsafe[i]
      end
      size
    end
  end

  def [](idx : Int)
    abort "accessing out of bounds!" unless 0 <= idx < @size
    @buffer[idx]
  end

  def []?(idx : Int) : T?
    return nil unless 0 <= idx < @size
    @buffer[idx]
  end

  def []=(idx : Int, value : T)
    abort "accessing out of bounds!" unless 0 <= idx < @size
    @buffer[idx] = value
  end

  def push(value : T)
    write_barrier do
      if @size < @capacity
        @buffer[@size] = value
      else
        expand(@size + 1)
        @buffer[@size] = value
      end
      @size += 1
    end
  end

  def clear
    write_barrier do
      @size = 0
    end
  end

  @[NoInline]
  def mark(&block : Void* ->)
    return if @buffer.null?
    yield @buffer.as(Void*)
    {% unless T < Int || T < Struct %}
      each do |obj|
        yield obj.as(Void*)
      end
    {% end %}
  end
end
