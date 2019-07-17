require "./vfs.cr"

class KbdFsNode < VFSNode

    def size : Int
        0
    end
    def name : CString | Nil
        nil
    end

    #
    def open(path : Slice) : VFSNode | Nil
        nil
    end

    def read(&block)
    end

    def read(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process | Nil = nil) : Int32
        VFS_READ_WAIT
    end

    def write(slice : Slice) : Int32
        0
    end
end

class KbdFS < VFS

    def name
        @name.not_nil!
    end

    @next_node : VFS | Nil = nil
    property next_node

    def initialize(@keyboard : KeyboardInstance)
        @name = CString.new("kbd", 3)
        @root = KbdFsNode.new
    end

    def root
        @root.not_nil!
    end

    def on_key(ch)
    end

end