require "./vfs.cr"

class KbdFsNode < VFSNode

    @read_queue : VFSReadQueue | Nil = nil
    getter read_queue

    def initialize
        @read_queue = VFSReadQueue.new
    end

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

    def initialize(@keyboard : Keyboard)
        @name = CString.new("kbd", 3)
        @root = KbdFsNode.new
    end

    def root
        @root.not_nil!
    end

    def on_key(ch)
        byte = case ch
        when Char
            ch.ord.to_u8
        when UInt32
            ch.to_u8
        end
        if byte.nil?
            byte = 0u8
        end
        VGA.puts ch

        last_page_dir = Paging.current_page_dir
        root.read_queue.not_nil!.select do |msg|
            #Serial.puts msg.slice, '\n'
            dir = msg.process.phys_page_dir
            Paging.current_page_dir = Pointer(PageStructs::PageDirectory).new(dir.to_u64)
            Paging.enable
            msg.slice[0] = byte
            msg.process.status = Multiprocessing::ProcessStatus::IoUnwait
            msg.process.frame.not_nil!.eax = 1
            false
        end

        Paging.current_page_dir = last_page_dir
        Paging.enable
    end

end