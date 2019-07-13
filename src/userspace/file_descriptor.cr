class FileDescriptor < Gc

    @node : VFSNode | Nil = nil
    getter node

    def initialize(@node)
    end

end