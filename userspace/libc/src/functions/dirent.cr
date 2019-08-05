lib LibC
  alias Ino_t = Int32

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

  struct DIR
    dirent : Dirent
    fd : Int32
  end
end

fun opendir(dirname : LibC::String) : LibC::DIR*
  dirp = Pointer(LibC::DIR).malloc
  if (dirp.value.fd = _open(dirname, 0, 0)) == SYSCALL_ERR
    dirp.free
    return Pointer(LibC::DIR).null
  end
  dirp
end

fun closedir(dirp : LibC::DIR*) : Int32
  close dirp.value.fd
  dirp.free
  0
end

fun readdir(dirp : LibC::DIR*) : LibC::Dirent*
  direntp = dirp.as(LibC::Dirent*)
  if LibC.sysenter(SC_READDIR, dirp.value.fd, direntp.address.to_u32) != SYSCALL_SUCCESS
    Pointer(LibC::Dirent).null
  else
    direntp
  end
end
