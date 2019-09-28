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

  def remove : Int32
    return VFS_ERR if @removed
    return VFS_ERR if @mmap_count > 0

    @npages.times do |i|
      FrameAllocator.declaim_addr(@pages[i].address & ~PTR_IDENTITY_MASK)
    end
    free_page_table @pages, @npages
    @pages = Pointer(Pointer(UInt8)).null
    
    @parent.remove self
    @removed = true
    VFS_OK
  end
  
  # maximum pages which can be allocated using the heap allocator
  MAX_ALLOC_PAGES = 1024 / 4
  
  # maximum size of a temp file
  MAX_SIZE = 0x1000 * (0x1000 / sizeof(UInt8*))
  
  @pages = Pointer(Pointer(UInt8)).null
  @npages = 0
  @size = 0
  
  private def alloc_page_table(npages)
    if npages > MAX_ALLOC_PAGES
      frame = FrameAllocator.claim_with_addr | PTR_IDENTITY_MASK
      Pointer(Pointer(UInt8)).new frame
    else
      Pointer(Pointer(UInt8)).mmalloc npages
    end
  end
  
  private def free_page_table(pages, npages)
    if npages > MAX_ALLOC_PAGES
      phys = pages.address & ~PTR_IDENTITY_MASK
      FrameAllocator.declaim_addr phys
    else
      pages.mfree
    end
  end
  
  private def init_pages(npages)
    if @npages == 0
      # allocate new buffer for page table
      @pages = alloc_page_table npages
      @npages = npages
      @npages.times do |i|
        frame = FrameAllocator.claim_with_addr | PTR_IDENTITY_MASK
        @pages[i] = Pointer(UInt8).new(frame)
        zero_page @pages[i]
      end
    elsif npages > @npages
      new_table_size = npages * sizeof(UInt8*)
    
      # reallocate if on heap
      if @npages < MAX_ALLOC_PAGES &&
         KernelArena.block_size_for_ptr(@pages) < new_table_size
        new_pages = alloc_page_table(npages)
        memcpy(new_pages.as(UInt8*), @pages.as(UInt8*), @npages.to_u64 * sizeof(UInt8*))
        free_page_table(@pages, @npages)
        @pages = new_pages
      end
      
      # create new pages
      i = npages
      while i < @npages
        frame = FrameAllocator.claim_with_addr | PTR_IDENTITY_MASK
        @pages[i] = Pointer(UInt8).new(frame)
        zero_page @pages[i]
        i += 1
      end
      
      @npages = npages
    end
  end

  def read(slice : Slice(UInt8), offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    return VFS_ERR if @removed
    return VFS_EOF if offset >= @size

    remaining = min(slice.size, @size)
    npages = remaining.div_ceil 0x1000
    foffset = 0
    npages.times do |i|
      copy_sz = min(remaining, 0x1000)
      memcpy slice.to_unsafe + foffset, @pages[i], copy_sz.to_u64
      remaining -= copy_sz
      foffset += copy_sz
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

    remaining = min(slice.size, @size)
    npages = remaining.div_ceil 0x1000
    foffset = 0
    npages.times do |i|
      copy_sz = min(remaining, 0x1000)
      memcpy @pages[i], slice.to_unsafe + foffset, copy_sz.to_u64
      remaining -= copy_sz
      foffset += copy_sz
    end
    foffset
  end
  
  def truncate(size : Int32) : Int32
    return @size if size > MAX_SIZE
    Serial.puts "trunc: ", size, ' ', MAX_SIZE, '\n'
    new_npages = size.div_ceil 0x1000
    if size > @size
      @size = size
      init_pages new_npages
      Serial.puts @pages, '\n'
    elsif size < @size
      @size = size
      while new_npages < @npages
        FrameAllocator.declaim_addr(@pages[new_npages].address & ~PTR_IDENTITY_MASK)
        @pages[new_npages] = Pointer(UInt8).null
        new_npages += 1
      end
    end
    @size
  end
  
  @mmap_count = 0

  def mmap(node : MemMapNode, process : Multiprocessing::Process) : Int32
    @mmap_count += 1
    Serial.puts "mmap size: ", node.size, '/', size, '\n'
    npages = min(node.size / 0x1000, @npages)
    npages.times do |i|
      phys = @pages[i].address & ~PTR_IDENTITY_MASK
      Paging.alloc_page_pg(node.addr + i * 0x1000, true, true, 1, phys)
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
