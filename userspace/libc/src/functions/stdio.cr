EOF = -1
STDIN  = 0
STDOUT = 1
STDERR = 2

struct FILE

  # TODO: file buffering

  @eof = false
  @fd = 0
  property eof, fd

  def initialize(@fd)
    @eof = false
  end

  # misc
  def fflush : Int32
    0
  end

  def feof
    @eof ? 1 : 0
  end

  # reading
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

  # getting
  def fgets(str, size)
    idx = read @fd, str, size
    if idx == SYSCALL_ERR
      # TODO
      abort
    end
    # TODO: handle line buffering
    str[idx] = 0u8
    str
  end

  def fgetc
    # return EOF if @eof
    retval = 0
    read @fd, pointerof(retval).as(LibC::String), 1
    retval
  end

  # rw
  def fread(ptr, size)
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

  @@stdin = FILE.new  STDIN
  @@stdout = FILE.new STDOUT
  @@stderr = FILE.new STDERR

  def stdin; @@stdin; end
  def stdout; @@stdout; end
  def stderr; @@stderr; end

  def init
    LibC.stdin  = pointerof(@@stdin).as(Void*)
    LibC.stdout = pointerof(@@stdout).as(Void*)
    LibC.stderr = pointerof(@@stderr).as(Void*)
  end

  def flush
    @@stdin.fflush
    @@stdout.fflush
    @@stderr.fflush
  end

end

# file operations
fun fopen(file : LibC::String, mode : LibC::String) : Void*
  # TODO: mode
  fd = open(file, 0)
  if fd == SYSCALL_ERR
    return Pointer(Void).null
  end
  stream = Pointer(FILE).malloc
  stream.value.eof = false
  stream.value.fd = fd
  stream.as(Void*)
end

fun fclose(stream : Void*) : Int32
  stream = stream.as(FILE*)
  close(stream.value.fd)
  stream.free
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
  ret = write(STDOUT, data, strlen(data).to_i32)
  ret += putchar '\n'.ord.to_i32
  ret
end

fun nputs(data : LibC::String, len : LibC::SizeT) : Int32
  write(STDOUT, data, len.to_i32)
end

fun putchar(c : Int32) : Int32
  buffer = uninitialized Int8[1]
  buffer.to_unsafe[0] = c.to_i8
  write(STDOUT, buffer.to_unsafe, 1)
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
  read(STDIN, pointerof(retval).as(LibC::String), 1)
  retval
end
