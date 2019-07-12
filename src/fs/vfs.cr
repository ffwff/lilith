abstract class VFSNode < Gc

    def size : Int
    end

    # NOTE: must not use break
    def read(vfs : VFS, &block)
    end

end

abstract struct VFS

    def open(path) : VFSNode
    end

end