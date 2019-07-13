abstract class VFSNode < Gc

    abstract def size : Int

    # NOTE: must not use break
    # abstract def read(vfs : VFS, &block)

end

abstract class VFS < Gc

    abstract def name

    abstract def next_node : VFS | Nil
    abstract def next_node=(x : VFS | Nil)

    abstract def open(path) : VFSNode

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

end