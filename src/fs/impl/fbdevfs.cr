lib FbdevFsData
  @[Packed]
  struct FbBitBlit
    source : UInt32
    x, y, width, height : UInt32
  end
end

class FbdevFsNode < VFSNode
  getter fs

  def initialize(@fs : FbdevFS)
  end

  def open(path : Slice) : VFSNode?
    nil
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    byte_size = FbdevState.buffer.size * sizeof(UInt32)
    if offset > byte_size
      VFS_ERR
    else
      size = min(slice.size, byte_size - offset)
      byte_buffer = FbdevState.buffer.to_unsafe.as(UInt8*) + offset
      # NOTE: use memcpy for faster memory copying
      memcpy(slice.to_unsafe, byte_buffer, size.to_usize)
      size
    end
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    byte_size = FbdevState.buffer.size * sizeof(UInt32)
    if offset > byte_size
      VFS_ERR
    else
      size = min(slice.size, byte_size - offset)
      byte_buffer = FbdevState.buffer.to_unsafe.as(UInt8*) + offset
      # NOTE: use memcpy for faster memory copying
      memcpy(byte_buffer, slice.to_unsafe, size.to_usize)
      size
    end
  end

  def ioctl(request : Int32, data : Void*) : Int32
    case request
    when SC_IOCTL_TIOCGWINSZ
      IoctlHandler.winsize(data, FbdevState.width, FbdevState.height, 1, 1)
    when SC_IOCTL_FB_BITBLIT
      arg = data.as(FbdevFsData::FbBitBlit*).value

      # source
      source_sz = arg.width * arg.height * 4
      source = checked_slice32(arg.source, source_sz)
      return -1 if source.nil?
      source = source.not_nil!.to_unsafe

      # blit
      byte_buffer = FbdevState.buffer.to_unsafe.as(UInt8*)
      if  arg.x == 0 && arg.y == 0 &&
          arg.width == FbdevState.width && arg.height == FbdevState.height
        copy_size = FbdevState.width * FbdevState.height * 4
        memcpy(byte_buffer, source, copy_size.to_usize)
      else
        arg.height.times do |y|
          fb_offset = y * FbdevState.width * 4
          copy_offset = y * arg.width * 4
          copy_size = arg.width * 4
          memcpy(byte_buffer + fb_offset, source + copy_offset, copy_size.to_usize)
        end
      end

      0
    else
      -1
    end
  end

  def read_queue
    nil
  end
end

class FbdevFS < VFS
  def name
    @name.not_nil!
  end

  @next_node : VFS? = nil
  property next_node

  def initialize
    @name = GcString.new "fb0" # TODO
    @root = FbdevFsNode.new self
  end

  def root
    @root.not_nil!
  end
end
