abstract class VFSNode < Gc

    def size : Int
    end

    def read(vfs : VFS, &block)
    end

end

abstract struct VFS

    def open(path) : VFSNode
    end

end