module ProcFS
  extend self

  # /proc/[pid]
  class ProcessNode < VFS::Node
    include VFS::Enumerable(VFS::Node)

    @name : String? = nil
    getter! name : String
    getter fs : VFS::FS
    property prev_node, next_node
    getter! process

    @first_child : VFS::Node? = nil
    getter first_child

    def initialize(@process : Multiprocessing::Process?, @parent : Node, @fs : FS,
                   @prev_node : ProcessNode? = nil,
                   @next_node : ProcessNode? = nil)
      @attributes |= VFS::Node::Attributes::Directory
      @name = process.pid.to_s
      add_child(ProcessStatusNode.new(self, @fs))
      unless process.kernel_process?
        add_child(ProcessMmapNode.new(self, @fs))
      end
    end

    def initialize(@parent : Node, @fs : FS,
                   @prev_node : ProcessNode? = nil,
                   @next_node : ProcessNode? = nil)
      @attributes |= VFS::Node::Attributes::Directory
      @name = "kernel"
      add_child(MemInfoNode.new(self, @fs))
      add_child(CPUInfoNode.new(self, @fs))
    end

    def remove : Int32
      return VFS_ERR if removed?
      process.remove false
      @parent.remove_child self
      @process = nil
      @attributes |= VFS::Node::Attributes::Removed
      VFS_OK
    end
  end

  # /proc/
  class Node < VFS::Node
    include VFS::Enumerable(ProcessNode)
    getter fs : VFS::FS, raw_node, first_child

    def initialize(@fs : FS)
      @attributes |= VFS::Node::Attributes::Directory
      @lookup_cache = LookupCache.new
      add_child(ProcessNode.new(self, @fs))
    end

    def create_for_process(process)
      add_child(ProcessNode.new(process, self, @fs))
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

    def add_child(node : ProcessNode)
      lookup_cache[node.name.not_nil!] = node.as(VFS::Node)
      node.next_node = @first_child
      unless @first_child.nil?
        @first_child.not_nil!.prev_node = node
      end
      @first_child = node
      node
    end

    def remove_child(node : ProcessNode)
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

  # /proc/[pid]/status
  class ProcessStatusNode < VFS::Node
    getter fs : VFS::FS

    def name
      "status"
    end

    @next_node : VFS::Node? = nil
    property next_node
    property parent

    def initialize(@parent : ProcessNode, @fs : FS)
    end

    def read(slice : Slice, offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      writer = SliceWriter.new(slice, offset.to_i32)
      pp = @parent.process

      writer << "Name: "
      writer << pp.name.not_nil!
      writer << "\n"
      writer << "State: "
      writer << pp.sched_data.status
      writer << "\n"

      unless pp.kernel_process?
        writer << "MemUsed: "
        writer << pp.udata.memory_used
        writer << " kB\n"
      end

      writer.offset
    end
  end

  # /proc/[pid]/mmap
  class ProcessMmapNode < VFS::Node
    getter fs : VFS::FS

    def name
      "mmap"
    end

    @next_node : VFS::Node? = nil
    property next_node
    property parent

    def initialize(@parent : ProcessNode, @fs : FS)
    end

    def read(slice : Slice, offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      writer = SliceWriter.new(slice, offset.to_i32)
      pp = @parent.process

      pp.udata.mmap_list.each do |node|
        writer << node
        writer << "\n"
      end

      writer.offset
    end
  end

  # /proc/kernel/meminfo
  class MemInfoNode < VFS::Node
    getter fs : VFS::FS

    def name
      "meminfo"
    end

    @next_node : VFS::Node? = nil
    property next_node
    property parent

    def initialize(@parent : ProcessNode, @fs : FS)
    end

    def read(slice : Slice, offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      writer = SliceWriter.new(slice, offset.to_i32)

      writer << "MemTotal: "
      writer << (Paging.usable_physical_memory // 1024)
      writer << " kB\n"

      writer << "MemUsed: "
      writer << (FrameAllocator.used_blocks * (0x1000 // 1024))
      writer << " kB\n"

      writer << "HeapSize: "
      writer << (Allocator.pages_allocated * (0x1000 // 1024))
      writer << " kB\n"

      writer.offset
    end
  end

  # /proc/kernel/cpuinfo
  class CPUInfoNode < VFS::Node
    getter fs : VFS::FS

    def name
      "cpuinfo"
    end

    @next_node : VFS::Node? = nil
    property next_node
    property parent

    def initialize(@parent : ProcessNode, @fs : FS)
    end

    def read(slice : Slice, offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      writer = SliceWriter.new(slice, offset.to_i32)

      writer << "Model name: "
      writer << X86::CPUID.brand
      writer << "\n"

      writer.offset
    end
  end

  class FS < VFS::FS
    getter! root : VFS::Node

    def name : String
      "proc"
    end

    def initialize
      @root = Node.new self
    end
  end
end
