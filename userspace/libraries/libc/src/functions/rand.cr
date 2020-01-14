module Random
  extend self

  # random numbers from python's random.randint(),
  # guaranteed to be random
  @@s : StaticArray(UInt32, 4) = StaticArray[
    786146064u32,
    1173352231u32,
    1007526471u32,
    110692341u32
  ]

  def rotl(x : UInt32, k : UInt32)
    (x << k) | (x >> (64 - k))
  end

  def xoshiro128ss
    result = rotl(@@s[1] * 5, 7) * 9
    t = @@s[1] << 9

    @@s[2] ^= @@s[0]
    @@s[3] ^= @@s[1]
    @@s[1] ^= @@s[2]
    @@s[0] ^= @@s[3]

    @@s[2] ^= t
    @@s[3] = rotl(@@s[3], 11)

    result
  end

end

fun rand : LibC::Int
  r = Random.xoshiro128ss
  (r ^ (r >> 31)).to_i32
end
