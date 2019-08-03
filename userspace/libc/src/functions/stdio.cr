EOF = -1

struct FILE

  # FIXME: IO doesnt work correctly

  @eof = false

  def initialize(@fd : Int32)
  end

  def fflush : Int32
    0
  end

  #
  def fgets(str, size)
    if @eof
      str[0] = 0u8
      return str
    end
    idx = read @fd, str, size
    if idx == SYSCALL_ERR
      # TODO
      abort
    end
    str[idx] = 0u8
    str
  end

  def fgetc
    return EOF if @eof
    retval = 0
    read @fd, pointerof(retval).as(LibC::String), 1
    if retval == 0
      @eof = true
    end
    retval
  end

  def feof
    @eof ? 1 : 0
  end

  def fputs(str)
    write(@fd, str, strlen(str).to_i32).to_i32
  end

  def fnputs(str, len)
    write(@fd, str, len.to_i32).to_i32
  end

  def fputc(c)
    buffer = uninitialized Int8[1]
    buffer.to_unsafe[0] = c.to_i8
    write(@fd, buffer.to_unsafe, 1).to_i32
  end

  # rw
  def fread(ptr, size)
    return 0u32 if @eof
    read(@fd, ptr.as(LibC::String), size.to_i32).to_u32
  end

  def fwrite(ptr, size)
    write(@fd, ptr.as(LibC::String), size.to_i32).to_u32
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
  abort
  Pointer(Void).null
end

fun fclose(stream : Void*) : Int32
  abort
  0
end

fun fflush(stream : Void*) : Int32
  stream.as(FILE*).value.fflush
end

fun fseek(stream : Void*, offset : Int32, whence : Int32) : Int32
  abort
  0
end

fun ftell(stream : Void*) : Int32
  abort
  0
end

fun fread(ptr : UInt8*, size : LibC::SizeT, nmemb : LibC::SizeT, stream : Void*) : LibC::SizeT
  stream.as(FILE*).value.fread ptr, size * nmemb
end

fun fwrite(ptr : UInt8*, size : LibC::SizeT, nmemb : LibC::SizeT, stream : Void*) : LibC::SizeT
  stream.as(FILE*).value.fwrite ptr, size * nmemb
end

fun fgets(str : LibC::String, size : Int32, stream : Void*) : LibC::String
  stream.as(FILE*).value.fgets str, size
end

fun fgetc(stream : Void*) : Int32
  stream.as(FILE*).value.fgetc
end

fun feof(stream : Void*) : Int32
  stream.as(FILE*).value.feof
end

fun fputs(str : LibC::String, stream : Void*) : Int32
  stream.as(FILE*).value.fputs str
end

fun fnputs(data : LibC::String, len : LibC::SizeT,  stream : Void*) : Int32
  stream.as(FILE*).value.fnputs data, len
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

fun putc(c : Int32, stream : Void*) : Int32
  stream.as(FILE*).value.fputc c
end

fun fputc(c : Int32, stream : Void*) : Int32
  stream.as(FILE*).value.fputc c
end

# get
fun getchar : Int32
  retval = 0
  read(0, pointerof(retval).as(LibC::String), 1)
  retval
end
