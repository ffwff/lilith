class FileDescriptor < Gc

    @node : VFSNode | Nil = nil
    getter node
    @offset = 0u32
    property offset

    def initialize(@node)
    end

end