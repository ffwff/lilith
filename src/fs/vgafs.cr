class VGAFsNode < VFSNode

    def initialize(@fs : VGAFS)
    end

    #
    def size : Int
        0
    end
    def name; end

    def parent; end
    def next_node; end
    def first_child; end

    #
    def open(path : Slice) : VFSNode | Nil
        nil
    end

    def read(&block)
    end

    def read(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process | Nil = nil) : Int32
        0
    end

    def write(slice : Slice) : Int32
        slice.each do |ch|
            VGA.puts ch.unsafe_chr
        end
        slice.size
    end

    def read_queue
        nil
    end

end

class VGAFS < VFS

    def name
        @name.not_nil!
    end

    @next_node : VFS | Nil = nil
    property next_node

    def initialize
        @name = GcString.new "vga"
        @root = VGAFsNode.new self
    end

    def root
        @root.not_nil!
    end

end