struct ArgvBuilder

  MAX_ARGS = 255

  @placement = 0
  @argc = 0
  def initialize(@process : Multiprocessing::Process)
  end

  # placement functions
  private def place(char : UInt8)
    # stack grows downwards in x86
    ptr = Pointer(UInt8).new((@process.initial_esp - @placement).to_u64)
    ptr[0] = char
    @placement += 1
  end

  private def place_u32(word : UInt32)
    ptr = Pointer(UInt32).new((@process.initial_esp - @placement).to_u64)
    ptr[0] = word
    @placement += sizeof(UInt32)
  end

  private def place_str(str)
    @placement += str.size + 1
    ptr = Pointer(UInt8).new((@process.initial_esp - @placement).to_u64)
    i = 0
    str.each do |char|
      ptr[i] = char.to_u8
      i += 1
    end
    ptr[i] = 0u8
  end

  # builder functions
  def from_string_array(argv : UInt8**)
    i = 0
    while i < MAX_ARGS
      if argv[i].null?
        return true
      elsif (ptr = checked_pointer(argv[i].address.to_u32)).nil?
        return false
      else
        place_str NullTerminatedSlice.new(argv[i])
      end
      @argc += 1
      i += 1
    end
    true
  end

  def from_string(arg : String)
    place_str arg
    @argc += 1
  end

  # build argv/argc
  def build
    # build argv
    scan_start = @process.initial_esp - @placement
    scan_end = @process.initial_esp
    @placement += sizeof(UInt32) # add padding for uint32
    place_u32 0u32 # null-terminate argv
    # iterate through args
    i = scan_start
    str_start = i
    while i < scan_end
      ptr = Pointer(UInt8).new(i.to_u64)
      if ptr.value == 0u8
        #Serial.puts Pointer(UInt8).new(str_start.to_u64), '\n'
        place_u32 str_start
        str_start = i + 1 # skip nul terminator
      end
      i += 1
    end
    # argv pointer
    argv_ptr = (@process.initial_esp - @placement + sizeof(UInt32))
    place_u32 argv_ptr.to_u32
    # argc
    place_u32 @argc.to_u32
    # finalize
    @process.initial_esp -= @placement
    #Serial.puts Pointer(UInt8).new(@process.initial_esp.to_u64),'\n'
    #breakpoint
  end

end