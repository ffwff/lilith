module TmpFS
  extend self

  class FrameArray < Array(UInt8*)
    def mark(&block : Void* ->)
      return if @buffer.null?
      yield @buffer.as(Void*)
    end
  end

  class Node < VFS::Node
    include VFS::Child(Node)

    getter! name : String, fs : VFS::FS
    getter size

    def initialize(@name : String, @fs : FS)
    end

    @frames : FrameArray? = nil
    @size = 0

    def remove : Int32
      return VFS_ERR if removed?
      if @mmap_count > 0
        Serial.print "tmpfs: can't remove if mmapd"
        return VFS_ERR
      end

      if frames = @frames
        frames.each do |frame|
          FrameAllocator.declaim_addr(frame.address & ~Paging::IDENTITY_MASK)
        end
        @frames = nil
      end

      @parent.as!(Root).remove_child self
      @attributes |= VFS::Node::Attributes::Removed
      VFS_OK
    end

    def read(slice : Slice(UInt8), offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      return VFS_ERR if removed?
      return VFS_EOF if offset >= @size

      foffset = 0
      remaining = Math.min(slice.size, @size)
      @frames.not_nil!.each do |frame|
        if offset > 0x1000
          offset -= 0x1000
        elsif offset >= 0
          copy_sz = Math.min(0x1000u64 - offset.to_u64, remaining.to_u64)
          memcpy slice.to_unsafe + foffset, frame + offset.to_u64, copy_sz
          foffset += copy_sz
          remaining -= copy_sz
          offset = 0u32
        end
      end
      foffset
    end

    def write(slice : Slice(UInt8), offset : UInt32,
              process : Multiprocessing::Process? = nil) : Int32
      return VFS_ERR if removed?
      return VFS_EOF if offset > @size
      
      if offset == @size
        truncate(@size.to_i32 + offset.to_i32 + slice.size.to_i32)
      end

      foffset = 0
      remaining = Math.min(slice.size, @size)
      @frames.not_nil!.each do |frame|
        if offset > 0x1000
          offset -= 0x1000
        elsif offset >= 0
          copy_sz = Math.min(0x1000u64 - offset.to_u64, remaining.to_u64)
          memcpy frame + offset.to_u64, slice.to_unsafe + foffset, copy_sz
          foffset += copy_sz
          remaining -= copy_sz
          offset = 0u32
        end
      end
      foffset
    end
    
    def truncate(size : Int32) : Int32
      npages = size.div_ceil 0x1000
      if @frames.nil?
        @frames = FrameArray.new(npages)
      end
      frames = @frames.not_nil!
      oldpages = frames.size
      if npages > oldpages
        delta = npages - oldpages
        delta.times do |i|
          frame = Pointer(UInt8).new(FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK)
          zero_page frame
          frames.push(frame)
        end
        @size = size
      end
      @size
    end
    
    @mmap_count = 0

    def mmap(node : MemMapList::Node, process : Multiprocessing::Process) : Int32
      if frames = @frames
        @mmap_count += 1
        npages = Math.min(node.size // 0x1000, frames.size)
        frames.each_with_index do |frame, idx|
          break if idx == npages
          phys = frame.address & ~Paging::IDENTITY_MASK
          Paging.alloc_page(node.addr + idx * 0x1000,
                node.attr.includes?(MemMapList::Node::Attributes::Write),
                true, 1, phys,
                execute: node.attr.includes?(MemMapList::Node::Attributes::Execute))
        end
        VFS_OK
      else
        VFS_ERR
      end
    end

    def munmap(addr : UInt64, size : UInt64, process : Multiprocessing::Process) : Int32
      @mmap_count -= 1
      abort "unimplemented"
      return 0
      {% if false %}
      i = addr
      end_addr = i + size
      while i < end_addr
        Paging.remove_page(i)
        i += 0x1000
      end
      VFS_OK
      {% end %}
    end
  end


  class Root < VFS::Node
    include VFS::Enumerable(Node)
    getter fs : VFS::FS
    
    def initialize(@fs : FS)
      @attributes |= VFS::Node::Attributes::Directory
    end

    def create(name : Slice, process : Multiprocessing::Process? = nil, options : Int32 = 0) : VFS::Node?
      node = Node.new(String.new(name), fs)
      add_child node
      node
    end
  end

  class FS < VFS::FS
    getter! root : VFS::Node

    def name : String
      "tmp"
    end

    def initialize
      @root = Root.new self
    end
  end
end
