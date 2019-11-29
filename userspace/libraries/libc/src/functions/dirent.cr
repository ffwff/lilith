lib LibC
  alias Ino_t = LibC::Int

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
    fd : LibC::Int
  end
end

fun opendir(dirname : UInt8*) : LibC::DIR*
  dirp = Pointer(LibC::DIR).malloc
  if (dirp.value.fd = _open(dirname, 0)) == SYSCALL_ERR
    dirp.free
    return Pointer(LibC::DIR).null
  end
  dirp
end

fun closedir(dirp : LibC::DIR*) : LibC::Int
  close dirp.value.fd
  dirp.free
  0
end

fun readdir(dirp : LibC::DIR*) : LibC::Dirent*
  if lilith_readdir(dirp.value.fd, dirp.as(Void*)) != SYSCALL_SUCCESS
    Pointer(LibC::Dirent).null
  else
    dirp.as(LibC::Dirent*)
  end
end
