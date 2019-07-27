struct GcPointer(T)
  getter ptr

  def initialize(@ptr : Pointer(T))
  end

  def self.null
    new Pointer(T).null
  end

  def self.malloc
    new LibGc.unsafe_malloc(sizeof(T), false)
  end

  def self.malloc(size)
    {% raise "must not be garbage collected type" if T < Gc %}
    new LibGc.unsafe_malloc(size.to_u32 * sizeof(T), true).as(Pointer(T))
  end
end