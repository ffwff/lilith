struct ArgvBuilder
  MAX_ARGS          =   255
  MAX_STR_PLACEMENT = 0x800

  @placement = 0
  @argc = 0

  def initialize(@process : Multiprocessing::Process)
  end

  # placement functions
  private def place(char : UInt8)
    # stack grows downwards in x86
    ptr = Pointer(UInt8).new((@process.initial_sp - @placement).to_u64)
    ptr[0] = char
    @placement += 1
  end

  private def place_u32(word : UInt32)
    ptr = Pointer(UInt32).new((@process.initial_sp - @placement).to_u64)
    ptr[0] = word
    @placement += sizeof(UInt32)
  end

  private def place_u64(word : UInt64)
    ptr = Pointer(UInt64).new((@process.initial_sp - @placement).to_u64)
    ptr[0] = word
    @placement += sizeof(UInt64)
  end

  private def place_str(str)
    d = str.bytesize + 1
    if @placement + d > MAX_STR_PLACEMENT
      return false
    end
    @placement += d
    ptr = Pointer(UInt8).new((@process.initial_sp - @placement).to_u64)
    i = 0
    str.each_byte do |char|
      ptr[i] = char.to_u8
      i += 1
    end
    ptr[i] = 0u8
    true
  end

  # builder functions
  def from_string(arg)
    if !place_str arg
      return false
    end
    @argc += 1
    true
  end

  # build argv/argc
  def build32
    # build argv
    scan_start = @process.initial_sp - @placement
    scan_end = @process.initial_sp
    @placement += sizeof(UInt32) # add padding for uint32
    place_u32 0u32               # null-terminate argv
    # iterate through args
    i = scan_start.to_u32
    str_start = i
    while i < scan_end
      ptr = Pointer(UInt8).new(i.to_u64)
      if ptr.value == 0u8
        # Serial.print Pointer(UInt8).new(str_start.to_u64), '\n'
        place_u32 str_start
        str_start = i + 1 # skip nul terminator
      end
      i += 1
    end
    # argv pointer
    argv_ptr = (@process.initial_sp - @placement + sizeof(UInt32))
    place_u32 argv_ptr.to_u32
    # argc
    place_u32 @argc.to_u32
    # finalize
    @process.initial_sp -= @placement
  end

  # build argv/argc
  def build64
    # build argv
    scan_start = @process.initial_sp - @placement
    scan_end = @process.initial_sp
    @placement += sizeof(UInt64) # add padding for uint32
    place_u64 0u32               # null-terminate argv
    # iterate through args
    i = scan_start.to_u64
    str_start = i
    while i < scan_end
      ptr = Pointer(UInt8).new(i)
      if ptr.value == 0u8
        # Serial.print Pointer(UInt8).new(str_start.to_u64), '\n'
        place_u64 str_start
        str_start = i + 1 # skip nul terminator
      end
      i += 1
    end
    # argv pointer
    argv_ptr = (@process.initial_sp - @placement + sizeof(UInt64))
    place_u64 argv_ptr.to_u64
    # argc
    place_u64 @argc.to_u64
    # finalize
    @process.initial_sp -= @placement
  end
end
