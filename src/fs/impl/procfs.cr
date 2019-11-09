class ProcFSNode < VFSNode
  @first_child : ProcFSProcessNode? = nil
  getter fs : VFS, raw_node, first_child

  def initialize(@fs : ProcFS)
    add_child(ProcFSProcessNode.new(self, @fs))
  end
  
  def open(path : Slice, process : Multiprocessing::Process? = nil) : VFSNode?
    node = @first_child
    while !node.nil?
      if node.not_nil!.name == path
        return node
      end
      node = node.next_node
    end
  end

  def create_for_process(process)
    add_child(ProcFSProcessNode.new(process, self, @fs))
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

  private def add_child(node : ProcFSProcessNode)
    node.next_node = @first_child
    unless @first_child.nil?
      @first_child.not_nil!.prev_node = node
    end
    @first_child = node
    node
  end

  def remove_child(node : ProcFSProcessNode)
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
class ProcFSProcessNode < VFSNode
  @name : String? = nil
  getter! name : String
  getter fs : VFS
  property prev_node, next_node

  @first_child : VFSNode? = nil
  getter first_child

  def process
    @process.not_nil!
  end

  def initialize(@process : Multiprocessing::Process?, @parent : ProcFSNode, @fs : ProcFS,
                 @prev_node : ProcFSProcessNode? = nil,
                 @next_node : ProcFSProcessNode? = nil)
    @name = process.pid.to_s
    add_child(ProcFSProcessStatusNode.new(self, @fs))
    unless process.kernel_process?
      add_child(ProcFSProcessMmapNode.new(self, @fs))
    end
  end

  def initialize(@parent : ProcFSNode, @fs : ProcFS,
                 @prev_node : ProcFSProcessNode? = nil,
                 @next_node : ProcFSProcessNode? = nil)
    @name = "kernel"
    add_child(ProcFSMemInfoNode.new(self, @fs))
  end

  def remove : Int32
    return VFS_ERR if process.removed?
    process.remove false
    @parent.remove_child self
    VFS_OK
  end
  
  def open(path : Slice, process : Multiprocessing::Process? = nil) : VFSNode?
    node = @first_child
    while !node.nil?
      if node.not_nil!.name == path
        return node
      end
      node = node.next_node
    end
  end

  private def add_child(child : VFSNode)
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
private class ProcFSProcessStatusNode < VFSNode
  getter fs : VFS

  def name
    "status"
  end

  @next_node : VFSNode? = nil
  property next_node

  def initialize(@parent : ProcFSProcessNode, @fs : ProcFS)
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

    writer.offset
  end
end

# /proc/[pid]/mmap
private class ProcFSProcessMmapNode < VFSNode
  getter fs : VFS

  def name
    "mmap"
  end

  @next_node : VFSNode? = nil
  property next_node

  def initialize(@parent : ProcFSProcessNode, @fs : ProcFS)
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

# kernel nodes

# /proc/meminfo
private class ProcFSMemInfoNode < VFSNode
  getter fs : VFS

  def name
    "meminfo"
  end

  @next_node : VFSNode? = nil
  property next_node

  def initialize(@parent : ProcFSProcessNode, @fs : ProcFS)
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

    writer.offset
  end
end

class ProcFS < VFS
  getter! root : VFSNode

  def name : String
    "proc"
  end

  def initialize
    @root = ProcFSNode.new self
  end
end
