class Array(T)

  @size : Int32
  @capacity : Int32
  getter size, capacity
  protected setter size

  def initialize
    @size = 0
    @capacity = 0
    @buffer = Pointer(T).null
  end

  def initialize(initial_capacity)
    @size = 0
    @capacity = initial_capacity
    if initial_capacity > 0
      @buffer = Pointer(T).malloc initial_capacity
    else
      @buffer = Pointer(T).null
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
    @buffer
  end

  def [](idx : Int)
    # TODO: bounds checking
    @buffer[idx]
  end

end
