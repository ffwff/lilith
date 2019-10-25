private lib FbdevFSData
  @[Packed]
  struct FbBitBlit
    target_buffer : TargetBuffer
    source : UInt32
    x, y, width, height : UInt32
    type : FbType
  end

  enum TargetBuffer : Int32
    Back  = 1
    Front = 0
  end

  enum FbType : Int32
    Surface      = 0
    Color        = 1
    SurfaceAlpha = 2
  end
end

private lib Kernel
  fun kalpha_blend(dst : UInt8*, src : UInt8*, yotsu : USize)
end

private class FbdevFSNode < VFSNode
  getter fs : VFS

  def initialize(@fs : FbdevFS)
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

  def ioctl(request : Int32, data : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    case request
    when SC_IOCTL_TIOCGWINSZ
      unless (ptr = checked_pointer(IoctlData::Winsize, data)).nil?
        retval = 0
        FbdevState.lock do |state|
          retval = IoctlHandler.winsize(ptr.not_nil!, state.width, state.height, 1, 1)
        end
        retval
      else
        -1
      end
    when SC_IOCTL_GFX_BITBLIT
      # TODO: this is deprecated and is only used for demo applications
      arg = checked_pointer(FbdevFSData::FbBitBlit, data)
      arg = if arg.nil?
              return -1
            else
              arg.not_nil!.value
            end

      if arg.type == FbdevFSData::FbType::Color
        FbdevState.lock do |state|
          byte_buffer = get_byte_buffer state, arg.target_buffer
          if arg.x == 0 && arg.y == 0 &&
             arg.width == state.width && arg.height == state.height
            copy_size = state.width.to_usize * state.height.to_usize
            memset_long(byte_buffer.as(UInt32*), arg.source, copy_size)
          else
            # TODO
          end
        end
        return 0
      end

      # source
      source_sz = arg.width * arg.height * 4
      source = checked_slice(arg.source, source_sz)
      return -1 if source.nil?
      source = source.not_nil!.to_unsafe

      # blit
      FbdevState.lock do |state|
        byte_buffer = get_byte_buffer state, arg.target_buffer
        if arg.x == 0 && arg.y == 0 &&
           arg.width == state.width && arg.height == state.height
          case arg.type
          when FbdevFSData::FbType::SurfaceAlpha
            copy_size = state.width * state.height
            Kernel.kalpha_blend(byte_buffer, source, copy_size.to_usize)
          when FbdevFSData::FbType::Surface
            copy_size = state.width * state.height * sizeof(UInt32)
            memcpy(byte_buffer, source, copy_size.to_usize)
          end
        else
          height = arg.height
          if arg.y + arg.height > state.height
            height = state.height - arg.y
          end

          width = arg.width
          if arg.x + arg.width > state.width
            width = state.width - arg.x
          end

          unless arg.x > state.width || arg.y > state.height
            case arg.type
            when FbdevFSData::FbType::SurfaceAlpha
              height.times do |y|
                fb_offset = (arg.y + y) * state.width * sizeof(UInt32) + arg.x * sizeof(UInt32)
                copy_offset = y * arg.width * sizeof(UInt32)
                copy_size = width // sizeof(UInt32)
                Kernel.kalpha_blend(byte_buffer + fb_offset, source + copy_offset, copy_size.to_usize)
              end
            when FbdevFSData::FbType::Surface
              height.times do |y|
                fb_offset = (arg.y + y) * state.width * sizeof(UInt32) + arg.x * sizeof(UInt32)
                copy_offset = y * arg.width * sizeof(UInt32)
                copy_size = width * sizeof(UInt32)
                memcpy(byte_buffer + fb_offset, source + copy_offset, copy_size.to_usize)
              end
            end
          end
        end
      end

      0
    when SC_IOCTL_GFX_SWAPBUF
      0
    else
      -1
    end
  end

  def mmap(node : MemMapNode, process : Multiprocessing::Process) : Int32
    npages = node.size // 0x1000
    FbdevState.lock do |state|
      phys_address = state.buffer.to_unsafe.address & ~PTR_IDENTITY_MASK
      Paging.alloc_page_pg node.addr, true, true, npages, phys_address
    end
    VFS_OK
  end

  def munmap(node : MemMapNode, process : Multiprocessing::Process) : Int32
    node.each_page do |page|
      Paging.remove_page(page)
    end
    VFS_OK
  end
end

class FbdevFS < VFS
  getter! root : VFSNode
  
  def name
    "fb0"
  end

  def initialize
    @root = FbdevFSNode.new self
  end
end
