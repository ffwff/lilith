module TmpFS
  extend self

  lib Data
    
    # FIXME: this is unportable for non 64-bit architectures
    MAX_FRAMES = (0x1000 - 8 * 3) // 8
    struct TmpFSPage
      prev_page : TmpFSPage*
      next_page : TmpFSPage*
      allocated_frames : Int64
      frames : (UInt8*)[MAX_FRAMES]
    end

  end

  class Node < VFS::Node
    include VFS::Child(Node)

    getter! name : String, fs : VFS::FS
    getter size

    def initialize(@name : String, @fs : FS)
    end

    @first_page = Pointer(Data::TmpFSPage).null
    @last_page = Pointer(Data::TmpFSPage).null
    @npages = 0
    @size = 0
    
    private def append_frame
      if @first_page.null?
        pframe = FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK
        @first_page = @last_page = Pointer(Data::TmpFSPage).new pframe
        zero_page @first_page.as(UInt8*)
      elsif @last_page.value.allocated_frames == Data::MAX_FRAMES
        frame = FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK
        page = Pointer(Data::TmpFSPage).new frame
        zero_page page.as(UInt8*)
        page.value.prev_page = @last_page
        @last_page.value.next_page = page
        @last_page = page
      end

      frame = FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK
      memset Pointer(UInt8).new(frame), 0, 0x1000
      len = @last_page.value.allocated_frames
      @last_page.value.frames[len] = Pointer(UInt8).new frame
      @last_page.value.allocated_frames = len + 1
    end

    private def pop_frame
      nlen = @last_page.value.allocated_frames - 1
      @last_page.value.allocated_frames = nlen
      frame = @last_page.value.frames[nlen]
      FrameAllocator.declaim_addr(frame.address & ~Paging::IDENTITY_MASK)
      @last_page.value.frames[nlen] = Pointer(UInt8).null

      if @last_page.value.allocated_frames == 0
        prev = @last_page.value.prev_page
        FrameAllocator.declaim_addr(@last_page.address & ~Paging::IDENTITY_MASK)
        @last_page = prev
      end
    end

    private def each_frame(&block)
      page = @first_page
      while !page.null?
        page.value.allocated_frames.times do |i|
          yield page.value.frames[i]
        end
        page = page.value.next_page
      end
    end

    def remove : Int32
      return VFS_ERR if removed?
      if @mmap_count > 0
        Serial.print "tmpfs: can't remove if mmapd"
        return VFS_ERR
      end

      page = @first_page
      while !page.null?
        page.value.allocated_frames.times do |i|
          frame = page.value.frames[i]
          FrameAllocator.declaim_addr(frame.address & ~Paging::IDENTITY_MASK)
        end
        next_page = page.value.next_page
        FrameAllocator.declaim_addr(page.address & ~Paging::IDENTITY_MASK)
        page = next_page
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
      each_frame do |frame|
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
      each_frame do |frame|
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
      new_npages = size.div_ceil 0x1000
      if size > @size
        @size = size
        while @npages < new_npages
          append_frame
          @npages += 1
        end
      elsif size < @size
        if @mmap_count > 0
          Serial.print "tmpfs: can't truncate if mmapd"
          return @size
        end
        @size = size
        while @npages > new_npages
          pop_frame
          @npages -= 1
        end
      end
      @size
    end
    
    @mmap_count = 0

    def mmap(node : MemMapList::Node, process : Multiprocessing::Process) : Int32
      @mmap_count += 1
      npages = Math.min(node.size // 0x1000, @npages)
      i = 0
      each_frame do |frame|
        break if i == npages
        phys = frame.address & ~Paging::IDENTITY_MASK
        Paging.alloc_page(node.addr + i * 0x1000,
              node.attr.includes?(MemMapList::Node::Attributes::Write),
              true, 1, phys,
              execute: node.attr.includes?(MemMapList::Node::Attributes::Execute))
        i += 1
      end
      VFS_OK
    end

    def munmap(addr : UInt64, size : UInt64, process : Multiprocessing::Process) : Int32
      @mmap_count -= 1
      i = addr
      end_addr = i + size
      while i < end_addr
        Paging.remove_page(i)
        i += 0x1000
      end
      VFS_OK
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
