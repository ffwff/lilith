EOF = -1
STDIN  = 0
STDOUT = 1
STDERR = 2

FILE_BUFFER_SZ = 256

class FileBuffer

  @buffer = Pointer(UInt8).null
  @pos = 0

  def initialize(@is_write = false)
  end

  def lazy_init
    if @buffer.null?
      @buffer = Pointer(UInt8).malloc FILE_BUFFER_SZ.to_u64
    end
  end

  def fwrite(fd : Int32, obuf : UInt8*, osize : Int32, line_buffered? = false)
    lazy_init
    offset = 0
    i = 0
    while i < osize
      if obuf[i] == '\n'.ord
        offset = i
      end
      @buffer[@pos] = obuf[i]
      @pos += 1
      if @pos == FILE_BUFFER_SZ
        if flush(fd) == EOF
          return i
        end
        offset = 0
      end
      i += 1
    end
    if line_buffered?
      pos = @pos
      @pos = offset
      if flush(fd) == EOF
        @pos = pos
        return i
      end
      @pos = pos - offset
      memmove(@buffer, @buffer + offset, @pos.to_u32)
    else
      flush fd
    end
    i
  end

  def flush(fd)
    retval = EOF
    if @is_write
      retval = write(fd, @buffer.as(LibC::String), @pos)
    end
    @pos = 0
    retval
  end

end

class File

  @[Flags]
  enum Status
    Read
    Write
    Append
    Binary
    EOF
  end

  enum Buffering
    Unbuffered
    LineBuffered
    FullyBuffered
  end

  # TODO: file buffering
  @status = Status::None
  @buffering = Buffering::Unbuffered
  @fd = 0
  property fd

  def initialize(@fd, @status, @buffering)
  end

  def _finalize
    close @fd
    # @wbuffer.free
    # @rbuffer.free
  end

  def parse_mode(mode)
    @status = Status::None
    until mode.value == 0
      ch = mode.value.unsafe_chr
      if ch == 'r'
        @status |= Status::Read
      elsif ch == 'w'
        @status |= Status::Write
      end
      mode += 1
    end
  end

  private def line_buffered?
    @buffering == Buffering::LineBuffered
  end

  # buffer
  @wbuffer = FileBuffer.new
  @rbuffer = FileBuffer.new

  # misc
  def fflush : Int32
    @wbuffer.flush(@fd) if @status.includes?(Status::Write)
    @rbuffer.flush(@fd) if @status.includes?(Status::Read)
    0
  end

  def feof
    @status.includes?(Status::EOF)
  end

  # reading
  def fputs(str)
    return 0 unless @status.includes?(Status::Write)
    len = strlen(str).to_i32
    if @buffering == Buffering::Unbuffered
      write(@fd, str, len).to_i32
    else
      @wbuffer.fwrite(@fd, str.as(UInt8*), len, line_buffered?)
    end
  end

  def fnputs(str, len)
    return 0 unless @status.includes?(Status::Write)
    if @buffering == Buffering::Unbuffered
      write(@fd, str, len.to_i32).to_i32
    else
      @wbuffer.fwrite(@fd, str.as(UInt8*), len.to_i32, line_buffered?)
    end
  end

  def fputc(c)
    return 0 unless @status.includes?(Status::Write)
    buffer = uninitialized Int8[1]
    buffer.to_unsafe[0] = c.to_i8
    write(@fd, buffer.to_unsafe, 1).to_i32
  end

  # getting
  def fgets(str, size)
    return str unless @status.includes?(Status::Read)
    if @buffering == Buffering::Unbuffered
      idx = read @fd, str, size
      if idx == SYSCALL_ERR
        # TODO
        abort
      end
      # TODO: handle line buffering
      str[idx] = 0u8
      str
    else
      abort
      str
    end
  end

  def fgetc
    return 0 unless @status.includes?(Status::Read)
    if @buffering == Buffering::Unbuffered
      retval = 0
      read @fd, pointerof(retval).as(LibC::String), 1
      retval
    else
      abort
      0
    end
  end

  # rw
  def fread(ptr, len)
    return 0u32 unless @status.includes?(Status::Read)
    if @buffering == Buffering::Unbuffered
      read(@fd, ptr.as(LibC::String), len.to_i32).to_u32
    else
      abort
      0u32
    end
  end

  def fwrite(ptr, len)
    return 0u32 unless @status.includes?(Status::Write)
    if @buffering == Buffering::Unbuffered
      write(@fd, ptr.as(LibC::String), len.to_i32).to_u32
    else
      ret = @wbuffer.fwrite(@fd, ptr.as(UInt8*), len.to_i32, line_buffered?)
      ret == EOF ? 0u32 : ret.to_u32
    end
  end

end

lib LibC
  $stdin : Void*
  $stdout : Void*
  $stderr : Void*
end

module Stdio
  extend self

  @@stdin  = File.new STDIN , File::Status::Read , File::Buffering::Unbuffered
  @@stdout = File.new STDOUT, File::Status::Write, File::Buffering::LineBuffered
  @@stderr = File.new STDERR, File::Status::Write, File::Buffering::Unbuffered

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
  fd = open(file, 0, 0)
  if fd.to_u32 == SYSCALL_ERR
    return Pointer(Void).null
  end
  stream = Pointer(File).malloc
  stream.value.fd = fd
  stream.value.parse_mode mode
  stream.as(Void*)
end

fun fclose(stream : Void*) : Int32
  stream = stream.as(File*)
  stream.value._finalize
  unless stream.value.fd <= STDERR
    # TODO
    stream.free
  end
  0
end

fun fflush(stream : Void*) : Int32
  stream.as(File*).value.fflush
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
  stream.as(File*).value.fread ptr, size * nmemb
end

fun fwrite(ptr : UInt8*, size : LibC::SizeT, nmemb : LibC::SizeT, stream : Void*) : LibC::SizeT
  stream.as(File*).value.fwrite ptr, size * nmemb
end

fun fgets(str : LibC::String, size : Int32, stream : Void*) : LibC::String
  stream.as(File*).value.fgets str, size
end

fun fgetc(stream : Void*) : Int32
  stream.as(File*).value.fgetc
end

fun feof(stream : Void*) : Int32
  stream.as(File*).value.feof ? 1 : 0
end

fun fputs(str : LibC::String, stream : Void*) : Int32
  stream.as(File*).value.fputs str
end

fun fnputs(data : LibC::String, len : LibC::SizeT,  stream : Void*) : Int32
  stream.as(File*).value.fnputs data, len
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
  stream.as(File*).value.fputc c
end

fun fputc(c : Int32, stream : Void*) : Int32
  stream.as(File*).value.fputc c
end

# get
fun getchar : Int32
  retval = 0
  read(STDIN, pointerof(retval).as(LibC::String), 1)
  retval
end

fun getline(lineptr : LibC::String*, n : LibC::SizeT*, stream : Void*) : LibC::SSizeT
  # TODO
  0
  #stream.as(File*).value.getline lineptr, n
end

# errors
fun perror(s : LibC::String)
end