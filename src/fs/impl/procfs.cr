private module ProcFSStrings
  extend self
  
  private macro sgetter(name)
	def {{ name }}
	  @@{{ name }}.not_nil!
	end
  end
  
  STATUS = "status"
  sgetter(status)
  
  @@initialized = false

  def lazy_init
    return if @@initialized
	@@status = GcString.new(STATUS)
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

  private def add_child(child : ProcFSProcessNode)
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

class ProcFS < VFS
  getter name, root

  def initialize
    ProcFSStrings.lazy_init
    @name = GcString.new "proc"
    @root = ProcFSNode.new self
  end

end
