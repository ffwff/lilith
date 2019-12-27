class ProcFS::Node < VFS::Node
  @first_child : ProcFS::ProcessNode? = nil
  getter fs : VFS::FS, raw_node, first_child

  def initialize(@fs : ProcFS::FS)
    @lookup_cache = LookupCache.new
    add_child(ProcFS::ProcessNode.new(self, @fs))
  end

  def open(path : Slice, process : Multiprocessing::Process? = nil) : VFS::Node?
    node = @first_child
    while !node.nil?
      if node.not_nil!.name == path
        return node
      end
      node = node.next_node
    end
  end

  def create_for_process(process)
    add_child(ProcFS::ProcessNode.new(process, self, @fs))
  end

  def remove_for_process(process)
    node = @first_child
    while !node.nil?
      if node.not_nil!.process == process
        remove_child(node)
        return
      end
      node = node.next_node
    end
  end

  private def add_child(node : ProcFS::ProcessNode)
    lookup_cache[node.name.not_nil!] = node.as(VFS::Node)
    node.next_node = @first_child
    unless @first_child.nil?
      @first_child.not_nil!.prev_node = node
    end
    @first_child = node
    node
  end

  def remove_child(node : ProcFS::ProcessNode)
    if cache = @lookup_cache 
      cache.delete node.name.not_nil!
    end
    if node == @first_child
      @first_child = node.next_node
    end
    unless node.prev_node.nil?
      node.prev_node.not_nil!.next_node = node.next_node
    end
    unless node.next_node.nil?
      node.next_node.not_nil!.prev_node = node.prev_node
    end
    node.prev_node = nil
    node.next_node = nil
  end
end

# process nodes

# /proc/[pid]
class ProcFS::ProcessNode < VFS::Node
  @name : String? = nil
  getter! name : String
  getter fs : VFS::FS
  property prev_node, next_node
  getter! process

  @first_child : VFS::Node? = nil
  getter first_child

  def initialize(@process : Multiprocessing::Process?, @parent : ProcFS::Node, @fs : ProcFS::FS,
                 @prev_node : ProcFS::ProcessNode? = nil,
                 @next_node : ProcFS::ProcessNode? = nil)
    @name = process.pid.to_s
    add_child(ProcFS::ProcessStatusNode.new(self, @fs))
    unless process.kernel_process?
      add_child(ProcFS::ProcessMmapNode.new(self, @fs))
    end
  end

  def initialize(@parent : ProcFS::Node, @fs : ProcFS::FS,
                 @prev_node : ProcFS::ProcessNode? = nil,
                 @next_node : ProcFS::ProcessNode? = nil)
    @name = "kernel"
    add_child(ProcFS::MemInfoNode.new(self, @fs))
  end

  def remove : Int32
    return VFS_ERR if removed?
    process.remove false
    @parent.remove_child self
    @process = nil
    @attributes |= VFS::Node::Attributes::Removed
    VFS_OK
  end

  def open(path : Slice, process : Multiprocessing::Process? = nil) : VFS::Node?
    node = @first_child
    while !node.nil?
      if node.not_nil!.name == path
        return node
      end
      node = node.next_node
    end
  end

  private def add_child(child : VFS::Node)
    if @first_child.nil?
      # first node
      child.next_node = nil
      @first_child = child
    else
      # middle node
      child.next_node = @first_child
      @first_child = child
    end
    child
  end
end

# /proc/[pid]/status
class ProcFS::ProcessStatusNode < VFS::Node
  getter fs : VFS::FS

  def name
    "status"
  end

  @next_node : VFS::Node? = nil
  property next_node

  def initialize(@parent : ProcFS::ProcessNode, @fs : ProcFS::FS)
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    writer = SliceWriter.new(slice, offset.to_i32)
    pp = @parent.process

    SliceWriter.fwrite? writer, "Name: "
    SliceWriter.fwrite? writer, pp.name.not_nil!
    SliceWriter.fwrite? writer, "\n"
    SliceWriter.fwrite? writer, "State: "
    SliceWriter.fwrite? writer, pp.sched_data.status
    SliceWriter.fwrite? writer, "\n"

    unless pp.kernel_process?
      SliceWriter.fwrite? writer, "MemUsed: "
      SliceWriter.fwrite? writer, pp.udata.memory_used
      SliceWriter.fwrite? writer, " kB\n"
    end

    writer.offset
  end
end

# /proc/[pid]/mmap
class ProcFS::ProcessMmapNode < VFS::Node
  getter fs : VFS::FS

  def name
    "mmap"
  end

  @next_node : VFS::Node? = nil
  property next_node

  def initialize(@parent : ProcFS::ProcessNode, @fs : ProcFS::FS)
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    writer = SliceWriter.new(slice, offset.to_i32)
    pp = @parent.process

    pp.udata.mmap_list.each do |node|
      SliceWriter.fwrite? writer, node
      SliceWriter.fwrite? writer, "\n"
    end

    writer.offset
  end
end

# /proc/meminfo
class ProcFS::MemInfoNode < VFS::Node
  getter fs : VFS::FS

  def name
    "meminfo"
  end

  @next_node : VFS::Node? = nil
  property next_node

  def initialize(@parent : ProcFS::ProcessNode, @fs : ProcFS::FS)
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    writer = SliceWriter.new(slice, offset.to_i32)

    SliceWriter.fwrite? writer, "MemTotal: "
    SliceWriter.fwrite? writer, (Paging.usable_physical_memory // 1024)
    SliceWriter.fwrite? writer, " kB\n"

    SliceWriter.fwrite? writer, "MemUsed: "
    SliceWriter.fwrite? writer, (FrameAllocator.used_blocks * (0x1000 // 1024))
    SliceWriter.fwrite? writer, " kB\n"

    SliceWriter.fwrite? writer, "HeapSize: "
    SliceWriter.fwrite? writer, (Allocator.pages_allocated * (0x1000 // 1024))
    SliceWriter.fwrite? writer, " kB\n"

    writer.offset
  end
end

class ProcFS::FS < VFS::FS
  getter! root : VFS::Node

  def name : String
    "proc"
  end

  def initialize
    @root = ProcFS::Node.new self
  end
end
