struct Hasher
  C = 0xc6a4a7935bd1e995u64
  R =                 47u64

  @@seed = 0xdeadbeefdeadbeefu64

  def initialize(@hash : UInt64 = @@seed)
  end

  def hash(bytes : Slice(UInt8))
    qwordp = bytes.to_unsafe.as(UInt64*)
    qwordl = bytes.size // 8
    qwordl.times do |i|
      hash_qword qwordp[i]
    end

    data2 = (qwordp + qwordl).as(UInt8*)
    rem = bytes.size & 7
    hash_small data2, rem

    self
  end

  def result
    @hash ^= (@hash >> R)
    @hash *= C
    @hash ^= (@hash >> R)
    @hash
  end

  private def hash_qword(k : UInt64)
    k *= C
    k ^= (k >> R)
    k *= C

    @hash ^= k
    @hash *= C
  end

  private def hash_small(ptr, rem)
    @hash ^= (ptr[6].to_u64 << 48u64) if rem >= 7
    @hash ^= (ptr[5].to_u64 << 40u64) if rem >= 6
    @hash ^= (ptr[4].to_u64 << 32u64) if rem >= 5
    @hash ^= (ptr[3].to_u64 << 24u64) if rem >= 4
    @hash ^= (ptr[2].to_u64 << 16u64) if rem >= 3
    @hash ^= (ptr[1].to_u64 << 8u64) if rem >= 2
    @hash ^= ptr[0].to_u64 if rem >= 1
    @hash *= C
  end

  def hash(int : Int)
    hash_qword int.to_u64
  end

  def hash(str : String)
    hash(str.byte_slice)
  end
end
