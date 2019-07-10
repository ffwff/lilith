abstract class VFSNode < Gc

    def read(vfs : VFS, &block)
    end

end

abstract struct VFS

    def open(path) : VFSNode
    end

end