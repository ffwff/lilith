lib LibC
  alias Ino_t = LibC::Int

  @[Packed]
  struct Dirent
    # Inode number
    d_ino : Ino_t
    # Length of this record
    d_reclen : UInt16
    # Type of file; not supported by all filesystem types
    d_type : UInt8
    # Null-terminated filename
    d_name : UInt8[256]
  end

  fun lilith_readdir(fd : LibC::Int,
                     direntp : Dirent*) : LibC::Int
  fun getcwd(path : LibC::UString, length : LibC::SizeT) : LibC::UString
  fun chdir(path : LibC::UString) : LibC::Int

  O_RDONLY = 1 << 0
  O_WRONLY = 1 << 1
  O_RDWR   = O_RDONLY | O_WRONLY
  O_CREAT  = 1 << 2
  O_TRUNC  = 1 << 3
  O_APPEND = 1 << 4
  C_ANON   = 1 << 24

  @[Flags]
  enum FileAttributes : Int32
    Removed   = 1 << 0
    Anonymous = 1 << 1
    Directory = 1 << 2
  end

  fun remove(filename : LibC::UString) : LibC::Int
  fun open(filename : LibC::UString, mode : LibC::Int) : LibC::Int
  fun _open(filename : LibC::UString, mode : LibC::Int) : LibC::Int
  fun read(fd : LibC::Int, str : LibC::String, len : LibC::Int) : LibC::Int
  fun write(fd : LibC::Int, str : LibC::String, len : LibC::Int) : LibC::Int
  fun waitfd(fds : LibC::Int*, nfd : LibC::SizeT, timeout : UInt64) : LibC::Int
  fun close(fd : LibC::Int) : LibC::Int
  fun fattr(fd : LibC::Int) : FileAttributes
  fun create(filename : LibC::UString, mode : LibC::Int) : LibC::Int
  fun mmap(addr : Void*, size : LibC::SizeT, prot : LibC::Int,
           flags : LibC::Int, fd : LibC::Int, offset : LibC::OffT) : Void*
  fun munmap(addr : Void*)
  fun lseek(fd : LibC::Int, offset : Int32, whence : LibC::Int) : Int32
  fun _ioctl(fd : LibC::Int, request : LibC::Int, data : UInt64) : LibC::Int
  fun ftruncate(fd : LibC::Int, size : LibC::Int) : LibC::Int

  fun abort : NoReturn
  fun usleep(timeout : UInt64) : LibC::Int
  fun exit(code : LibC::Int) : NoReturn

  SEEK_SET = 0
  SEEK_CUR = 1
  SEEK_END = 2

  @[Flags]
  enum MmapProt : LibC::Int
    Read    = 1 << 0
    Write   = 1 << 1
    Execute = 1 << 2
  end

  @[Packed]
  struct StartupInfo
    stdin : Int32
    stdout : Int32
    stderr : Int32
  end

  fun spawnxv(startup_info : StartupInfo*, file : LibC::UString, argv : UInt8**) : LibC::Pid
  fun waitpid(pid : LibC::Pid, status : LibC::Int*, options : LibC::Int) : LibC::Pid
end
