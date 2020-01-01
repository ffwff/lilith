module PermaAllocator
  extend self

  @@addr = 0u64
  class_property addr

  @@start = 0u64
  class_property start

  def malloc(size)
    last = @@addr
    @@addr += size
    Pointer(Void).new(last)
  end

  def malloc_t(type : T.class) forall T
    malloc(sizeof(T)).as(T*)
  end

  def malloca(size)
    if (@@addr & 0xFFFF_FFFF_FFFF_F000) != 0
      @@addr = (@@addr & 0xFFFF_FFFF_FFFF_F000) + 0x1000
    end
    malloc(size)
  end

  def malloca_t(type : T.class) forall T
    malloca(sizeof(T)).as(T*)
  end
end
