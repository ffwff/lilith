require "./async.cr"

module VFS
  extend self

  module Enumerable(T)
    def open(path : Slice, process : Multiprocessing::Process? = nil) : VFS::Node?
      return unless directory?
      each_child do |node|
        if node.name == path
          return node
        end
      end
    end

    def each_child(&block)
      if directory? && !dir_populated
        return
      end
      node = first_child
      while !node.nil?
        yield node.not_nil!
        node = node.next_node
      end
    end

    def add_child(child : T)
      if @first_child.nil?
        # first node
        child.next_node = nil
        @first_child = child
      else
        # middle node
        child.next_node = @first_child
        @first_child = child
      end
      child.parent = self
      child
    end

    def remove_child(node : T)
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

  abstract class Node
    enum Buffering
      Unbuffered
      LineBuffered
      FullyBuffered
    end

    def size : Int
      0
    end

    def name : String?
    end

    abstract def fs : VFS::FS

    @[Flags]
    enum Attributes : UInt32
      Removed   = 1 << 0
      Anonymous = 1 << 1
      Directory = 1 << 2
    end
    @attributes : Attributes = Attributes::None
    getter attributes

    def removed?
      @attributes.includes?(Attributes::Removed)
    end

    def directory?
      @attributes.includes?(Attributes::Directory)
    end

    def anonymous?
      @attributes.includes?(Attributes::Anonymous)
    end

    def parent : Node?
    end

    def next_node : Node?
    end

    def first_child : Node?
    end

    def populate_directory : Int32
      VFS_OK
    end

    def dir_populated : Bool
      true
    end

    # used for internal file execution
    def read(&block)
    end

    def open(path : Slice, process : Multiprocessing::Process? = nil) : Node?
    end

    def clone
    end

    def close
    end

    def create(name : Slice, process : Multiprocessing::Process? = nil, options : Int32 = 0) : Node?
    end

    def remove(process : Multiprocessing::Process? = nil) : Int32
      VFS_ERR
    end

    def read(slice : Slice(UInt8), offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      VFS_ERR
    end

    def write(slice : Slice(UInt8), offset : UInt32,
              process : Multiprocessing::Process? = nil) : Int32
      VFS_ERR
    end

    def spawn(udata : Multiprocessing::Process::UserData) : Int32
      VFS_ERR
    end

    def truncate(size : Int32) : Int32
      VFS_ERR
    end

    def ioctl(request : Int32, data : UInt64,
              process : Multiprocessing::Process? = nil) : Int32
      VFS_ERR
    end

    def mmap(node : MemMapList::Node, process : Multiprocessing::Process) : Int32
      VFS_ERR
    end

    def munmap(addr : UInt64, size : UInt64, process : Multiprocessing::Process) : Int32
      VFS_ERR
    end

    def available?(process : Multiprocessing::Process) : Bool
      true
    end

    def queue : Queue?
    end

    alias LookupCache = Hash(String, VFS::Node)
    @lookup_cache : LookupCache? = nil
    getter! lookup_cache

    def open_cached?(path : Slice)
      if cache = @lookup_cache
        cache[path]?
      end
    end
  end

  abstract class FS
    abstract def name : String

    def queue : Queue?
    end

    @next_node : FS? = nil
    @prev_node : FS? = nil
    property next_node, prev_node

    abstract def root : Node
  end
end

module RootFS
  extend self

  @@first_node : VFS::FS? = nil

  @@lookup_cache : Hash(String, VFS::FS)? = nil
  protected class_getter! lookup_cache

  @@root_device : VFS::FS? = nil
  class_property root_device

  def append(node : VFS::FS)
    if @@first_node.nil?
      node.next_node = nil
      node.prev_node = nil
      @@first_node = node
    else
      node.next_node = @@first_node
      @@first_node.not_nil!.prev_node = node
      @@first_node = node
    end
    if @@lookup_cache.nil?
      @@lookup_cache = Hash(String, VFS::FS).new
    end
    lookup_cache[node.name] = node.as(VFS::FS)
    node
  end

  def remove(node : VFS::FS)
    unless node.next_node.nil?
      node.next_node.not_nil!.prev_node = node.prev_node
    end
    if node.prev_node.nil?
      @@first_node = node.next_node
    else
      node.prev_node.not_nil!.next_node = node.next_node
    end
    lookup_cache.delete name
  end
  
  def find_root(name)
    if name == MAIN_PATH
      @@root_device.not_nil!.root
    elsif node = lookup_cache[name]?
      node.root
    end
  end
end

VFS_OK         =  0
VFS_ERR        = -1
VFS_WAIT       = -2
VFS_WAIT_QUEUE = -3
VFS_EOF        = -4

VFS_CREATE_ANON = 1 << 24
