class FileDescriptor < Gc

    @node : VFSNode | Nil = nil
    getter node
    @offset = 0u32
    property offset

    # used for readdir syscall
    @cur_child : VFSNode | Nil = nil
    property cur_child
    @cur_child_end = false
    property cur_child_end

    def initialize(@node)
    end

end