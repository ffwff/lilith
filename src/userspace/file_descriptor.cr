class FileDescriptor < Gc

    @vfs_node : VFSNode | Nil = nil

    def initialize(@vfs_node)
    end

end