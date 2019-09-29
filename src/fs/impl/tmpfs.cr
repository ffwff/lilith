private lib TmpFSData
  
  # FIXME: this is unportable for non 64-bit architectures
  MAX_FRAMES = (0x1000 - 8 * 3) / 8
  struct TmpFSPage
    prev_page : TmpFSPage*
    next_page : TmpFSPage*
    allocated_frames : Int64
    frames : (UInt8*)[MAX_FRAMES]
  end

end

private class TmpFSRoot < VFSNode
  getter fs
  
  def initialize(@fs : TmpFS)
  end

  def open(path : Slice) : VFSNode?
    each_child do |node|
      return node if node.name == path
    end
  end

  def create(name : Slice, process : Multiprocessing::Process? = nil) : VFSNode?
    each_child do |node|
      return if node.name == name
    end
    node = TmpFSNode.new(GcString.new(name), self, fs)
    node.next_node = @first_child
    unless @first_child.nil?
      @first_child.not_nil!.prev_node = node
    end
    @first_child = node
    node
  end

  def remove(node : TmpFSNode)
    if node == @first_child
      @first_child = node.next_node
    end
    unless node.prev_node.nil?
      node.prev_node.not_nil!.next_node = node.next_node
    end
    unless node.next_node.nil?
      node.next_node.not_nil!.prev_node = node.prev_node
    end
  end

  @first_child : TmpFSNode? = nil
  getter first_child

  def each_child(&block)
    node = @first_child
    while !node.nil?
      yield node.not_nil!
      node = node.next_node
    end
  end
end

private class TmpFSNode < VFSNode
  getter name, size, fs

  @next_node : TmpFSNode? = nil
  property next_node

  @prev_node : TmpFSNode? = nil
  property prev_node

  def initialize(@name : GcString, @parent : TmpFSRoot, @fs : TmpFS)
  end

  @removed = false
  @first_page = Pointer(TmpFSData::TmpFSPage).null
  @last_page = Pointer(TmpFSData::TmpFSPage).null
  @npages = 0
  @size = 0
  
  # page operations
  
  private def append_frame
    if @first_page.null?
      pframe = FrameAllocator.claim_with_addr | PTR_IDENTITY_MASK
      @first_page = @last_page = Pointer(TmpFSData::TmpFSPage).new pframe
      zero_page @first_page.as(UInt8*)
    elsif @last_page.value.allocated_frames == TmpFSData::MAX_FRAMES
      frame = FrameAllocator.claim_with_addr | PTR_IDENTITY_MASK
      page = Pointer(TmpFSData::TmpFSPage).new frame
      zero_page page.as(UInt8*)
      page.value.prev_page = @last_page
      @last_page.value.next_page = page
      @last_page = page
    end

    frame = FrameAllocator.claim_with_addr | PTR_IDENTITY_MASK
    len = @last_page.value.allocated_frames
    @last_page.value.frames[len] = Pointer(UInt8).new frame
    @last_page.value.allocated_frames = len + 1
  end

  private def pop_frame
    if @last_page.value.allocated_frames == 0
      prev = @last_page.value.prev_page
      FrameAllocator.declaim_addr(@last_page.address & ~PTR_IDENTITY_MASK)
      @last_page = prev
    else
      nlen = @last_page.value.allocated_frames - 1
      @last_page.value.allocated_frames = nlen
      frame = @last_page.value.frames[nlen]
      FrameAllocator.declaim_addr(frame.address & ~PTR_IDENTITY_MASK)
      @last_page.value.frames[nlen] = Pointer(UInt8).null
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
  
  # file operations

  def remove : Int32
    return VFS_ERR if @removed || @mmap_count > 0
    
    Serial.puts "removing\n"

    page = @first_page
    while !page.null?
      page.value.allocated_frames.times do |i|
        frame = page.value.frames[i]
        FrameAllocator.declaim_addr(frame.address & ~PTR_IDENTITY_MASK)
      end
      next_page = page.value.next_page
      FrameAllocator.declaim_addr(page.address & ~PTR_IDENTITY_MASK)
      page = next_page
    end

    @parent.remove self
    @removed = true
    VFS_OK
  end

  def read(slice : Slice(UInt8), offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    return VFS_ERR if @removed
    return VFS_EOF if offset >= @size

    foffset = 0
    remaining = min(slice.size, @size)
    each_frame do |frame|
      if offset > 0x1000
        offset -= 0x1000
      elsif offset >= 0
        copy_sz = min(0x1000u64 - offset.to_u64, remaining.to_u64)
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
    return VFS_ERR if @removed
    return VFS_EOF if offset > @size
    
    if offset == @size
      truncate(@size.to_i32 + offset.to_i32 + slice.size.to_i32)
    end

    foffset = 0
    remaining = min(slice.size, @size)
    each_frame do |frame|
      if offset > 0x1000
        offset -= 0x1000
      elsif offset >= 0
        copy_sz = min(0x1000u64 - offset.to_u64, remaining.to_u64)
        memcpy frame + offset.to_u64, slice.to_unsafe + foffset, copy_sz
        foffset += copy_sz
        remaining -= copy_sz
        offset = 0u32
      end
    end
    foffset
  end
  
  def truncate(size : Int32) : Int32
    Serial.puts "trunc: ", size, '\n'
    new_npages = size.div_ceil 0x1000
    if size > @size
      @size = size
      while @npages < new_npages
        append_frame
        @npages += 1
      end
    elsif size < @size
      @size = size
      while @npages > new_npages
        pop_frame
        @npages -= 1
      end
    end
    @size
  end
  
  @mmap_count = 0

  def mmap(node : MemMapNode, process : Multiprocessing::Process) : Int32
    @mmap_count += 1
    Serial.puts "mmap size: ", node.size, '/', size, '\n'
    npages = min(node.size / 0x1000, @npages)
    i = 0
    each_frame do |frame|
      break if i == npages
      phys = frame.address & ~PTR_IDENTITY_MASK
      Paging.alloc_page_pg(node.addr + i * 0x1000, true, true, 1, phys)
      i += 1
    end
    VFS_OK
  end

  def munmap(node : MemMapNode, process : Multiprocessing::Process) : Int32
    @mmap_count -= 1
    node.each_page do |page|
      Paging.remove_page(page)
    end
    VFS_OK
  end
end

class TmpFS < VFS
  def name
    @name.not_nil!
  end

  def initialize
    @name = GcString.new "tmp"
    @root = TmpFSRoot.new self
  end

  def root
    @root.not_nil!
  end
end
