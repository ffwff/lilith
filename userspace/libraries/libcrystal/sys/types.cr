lib LibC
  alias String = Int8*
  alias UString = UInt8*
  alias Pid = Int32

  alias SizeT = UInt32
  alias SSizeT = Int32
  alias Int = Int32
  alias UInt = UInt32
  alias Long = Int32
  alias ULong = UInt32
  alias LongLong = Int64
  alias ULongLong = UInt64
end

struct Int

  def to_int
    self.to_i32
  end

end
