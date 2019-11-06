lib LibC
  alias String = Int8*
  alias UString = UInt8*
  alias Pid = Int32

  alias Int = Int32
  alias UInt = UInt32
  alias LongLong = Int64
  alias ULongLong = UInt64

  {% if flag?(:bits32) %}
    alias SizeT = UInt32
    alias SSizeT = Int32
    alias Long = Int32
    alias ULong = UInt32
  {% else %}
    alias SizeT = UInt64
    alias SSizeT = Int64
    alias Long = Int64
    alias ULong = UInt64
  {% end %}
end

struct Int
  def to_int
    self.to_i32
  end

  def to_uint
    self.to_u32
  end

  {% if flag?(:bits32) %}
    def to_usize
      self.to_u32
    end
  {% else %}
    def to_usize
      self.to_u32
    end
  {% end %}
end
