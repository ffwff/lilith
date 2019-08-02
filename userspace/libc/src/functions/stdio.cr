struct FILE

  def initialize(@fd : Int32)
  end

  def flush : Int32
    0
  end

  def gets(str, size)
    idx = read @fd, str, size
    if idx == SYSCALL_ERR
      # TODO
      abort
    end
    str[idx] = 0u8
  end

  def puts(str)
  end

end

lib LibC
  $stdin : Void*
  $stdout : Void*
  $stderr : Void*
end

module Stdio
  extend self

  @@stdin = FILE.new 0
  @@stdout = FILE.new 1
  @@stderr = FILE.new 2

  def stdin; @@stdin; end
  def stdout; @@stdout; end
  def stderr; @@stderr; end

  def init
    LibC.stdin  = pointerof(@@stdin).as(Void*)
    LibC.stdout = pointerof(@@stdout).as(Void*)
    LibC.stderr = pointerof(@@stderr).as(Void*)
  end

end

# file operations
fun fopen(file : LibC::String, mode : LibC::String) : Void*
  Pointer(Void).null
end

fun fclose(stream : Void*) : Int32
  0
end

fun fflush(stream : Void*) : Int32
  stream.as(FILE*).value.flush
end

fun fseek(stream : Void*, offset : Int32, whence : Int32) : Int32
  0
end

fun ftell(stream : Void*) : Int32
  0
end

fun fread(ptr : UInt8*, size : LibC::SizeT, nmemb : LibC::SizeT, stream : Void*) : LibC::SizeT
  0u32
end

fun fwrite(ptr : UInt8*, size : LibC::SizeT, nmemb : LibC::SizeT, stream : Void*) : LibC::SizeT
  0u32
end

fun fgets(str : LibC::String, size : Int32, stream : Void*) : LibC::String
  stream.as(FILE*).value.gets str, size
  str
end

fun fputs(str : LibC::String, stream : Void*) : Int32
  0
end

# prints
fun puts(data : LibC::String) : Int32
  ret = write(1, data, strlen(data).to_i32)
  ret += putchar '\n'.ord.to_i32
  ret
end

fun nputs(data : LibC::String, len : LibC::SizeT) : Int32
  write(1, data, len.to_i32)
end

fun putchar(c : Int32) : Int32
  buffer = uninitialized Int8[1]
  buffer.to_unsafe[0] = c.to_i8
  write(1, buffer.to_unsafe, 1)
end
