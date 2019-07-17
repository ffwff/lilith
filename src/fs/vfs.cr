require "./async.cr"

abstract class VFSNode < Gc

    abstract def size : Int
    abstract def name : CString | Nil

    abstract def open(path : Slice) : VFSNode | Nil
    abstract def read(slice : Slice(UInt8), offset : UInt32,
        process : Multiprocessing::Process | Nil = nil) : Int32
    abstract def write(slice : Slice) : Int32

    abstract def read_queue : VFSReadQueue | Nil

end

abstract class VFS < Gc

    abstract def name : CString

    abstract def next_node : VFS | Nil
    abstract def next_node=(x : VFS | Nil)

    abstract def root : VFSNode

end

class RootFS < Gc

    @vfs_node : VFS | Nil = nil

    def initialize
    end

    def append(node : VFS)
        if @vfs_node.nil?
            node.next_node = nil
            @vfs_node = node
        else
            node.next_node = @vfs_node
            @vfs_node = node
        end
    end

    def each(&block)
        node = @vfs_node
        while !node.nil?
            yield node
            node = node.next_node
        end
    end

end

VFS_ERR = -1
VFS_READ_WAIT = -2