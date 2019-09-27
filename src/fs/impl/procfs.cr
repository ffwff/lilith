private module ProcFSStrings
  extend self
  
  private macro sgetter(name)
	def {{ name }}
	  @@{{ name }}.not_nil!
	end
  end
  
  STATUS = "status"
  MMAP = "mmap"

  sgetter(status)
  sgetter(mmap)
  
  @@initialized = false

  def lazy_init
    return if @@initialized
    @@status = GcString.new(STATUS)
    @@mmap = GcString.new(MMAP)
    @@initialized = true
  end

end

class ProcFSNode < VFSNode
  @first_child : ProcFSProcessNode? = nil
  getter fs, raw_node, first_child

  def initialize(@fs : ProcFS)
  end

  def open(path)
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
    @first_child = node
    unless @first_child.nil?
      @first_child.not_nil!.prev_node = node
    end
    node
  end
  
  private def remove_child(node : ProcFSProcessNode)
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

end

class ProcFSProcessNode < VFSNode
  @name : GcString? = nil
  getter name, fs
  property prev_node, next_node
  
  @first_child : VFSNode? = nil
  getter first_child
  
  getter process

  def initialize(@process : Multiprocessing::Process, @parent : ProcFSNode, @fs : ProcFS,
				 @prev_node : ProcFSProcessNode? = nil,
				 @next_node : ProcFSProcessNode? = nil)
    @name = @process.pid.to_gcstr
    add_child(ProcFSProcessStatusNode.new(self, @fs))
    unless @process.kernel_process?
      add_child(ProcFSProcessMmapNode.new(self, @fs))
    end
  end
  
  def open(path)
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

class ProcFSProcessStatusNode < VFSNode
  getter fs
  def name
    ProcFSStrings.status
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
    SliceWriter.fwrite? writer, pp.status
    SliceWriter.fwrite? writer, "\n"
     
    writer.offset
  end
end

class ProcFSProcessMmapNode < VFSNode
  getter fs
  def name
    ProcFSStrings.mmap
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

class ProcFS < VFS
  getter name, root

  def initialize
    ProcFSStrings.lazy_init
    @name = GcString.new "proc"
    @root = ProcFSNode.new self
  end

end
