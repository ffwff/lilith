class FbdevFS::Node < VFS::Node
  getter fs : VFS::FS

  def initialize(@fs : FbdevFS::FS)
  end

  def size
    byte_size = 0
    FbdevState.lock do |state|
      byte_size = state.buffer.size * sizeof(UInt32)
    end
    byte_size
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    FbdevState.lock do |state|
      byte_size = state.buffer.size * sizeof(UInt32)
      if offset > byte_size
        size = VFS_EOF
      else
        size = Math.min(slice.size, byte_size - offset)
        byte_buffer = state.buffer.to_unsafe.as(UInt8*) + offset
        # NOTE: use memcpy for faster memory copying
        memcpy(slice.to_unsafe, byte_buffer, size.to_usize)
      end
    end
    size
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    FbdevState.lock do |state|
      byte_size = state.buffer.size * sizeof(UInt32)
      if offset > byte_size
        size = VFS_EOF
      else
        size = Math.min(slice.size, byte_size - offset)
        byte_buffer = state.buffer.to_unsafe.as(UInt8*) + offset
        # NOTE: use memcpy for faster memory copying
        memcpy(byte_buffer, slice.to_unsafe, size.to_usize)
      end
    end
    size
  end

  private def get_byte_buffer(state, target_buffer)
    state.buffer.to_unsafe.as(UInt8*)
  end

  def ioctl(request : Int32, data : UInt64,
            process : Multiprocessing::Process? = nil) : Int32
    case request
    when SC_IOCTL_TIOCGWINSZ
      unless (ptr = checked_pointer(IoctlHandler::Data::Winsize, data)).nil?
        retval = 0
        FbdevState.lock do |state|
          retval = IoctlHandler.winsize(ptr.not_nil!, state.width, state.height, 1, 1)
        end
        retval
      else
        -1
      end
    else
      -1
    end
  end

  def mmap(node : MemMapList::Node, process : Multiprocessing::Process) : Int32
    npages = node.size // 0x1000
    node.attr &= ~MemMapList::Node::Attributes::Execute
    FbdevState.lock do |state|
      phys_address = state.buffer.to_unsafe.address & ~Paging::IDENTITY_MASK
      Paging.alloc_page node.addr,
        node.attr.includes?(MemMapList::Node::Attributes::Write),
        true, npages, phys_address
    end
    VFS_OK
  end

  def munmap(addr : UInt64, size : UInt64, process : Multiprocessing::Process) : Int32
    i = addr
    end_addr = i + size
    while i < end_addr
      Paging.remove_page(i)
      i += 0x1000
    end
    VFS_OK
  end
end

class FbdevFS::FS < VFS::FS
  getter! root : VFS::Node

  def name : String
    "fb0"
  end

  def initialize
    @root = FbdevFS::Node.new self
  end
end
