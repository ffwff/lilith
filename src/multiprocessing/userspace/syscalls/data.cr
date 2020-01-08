module Syscall
  extend self

  lib Data
    struct Registers
      ds : UInt64
      rbp, rdi, rsi,
r15, r14, r13, r12, r11, r10, r9, r8,
rdx, rcx, rbx, rax : UInt64
      rsp : UInt64
    end

    alias Ino32 = Int32

    @[Packed]
    struct DirentArgument32
      # Inode number
      d_ino : Ino32
      # Length of this record
      d_reclen : UInt16
      # Type of file; not supported by all filesystem types
      d_type : UInt8
      # Null-terminated filename
      d_name : UInt8[256]
    end

    @[Packed]
    struct SpawnStartupInfo32
      stdin : Int32
      stdout : Int32
      stderr : Int32
    end

    @[Flags]
    enum MmapProt : Int32
      Read    = 1 << 0
      Write   = 1 << 1
      Execute = 1 << 2
    end
  end
end
