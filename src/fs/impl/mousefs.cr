module MouseFS
  extend self

  lib Data
    enum MouseAttributes : UInt32
      LeftButton   = 1 << 0
      RightButton  = 1 << 1
      MiddleButton = 1 << 2
    end

    @[Packed]
    struct MousePacket
      x : UInt32
      y : UInt32
      attributes : MouseAttributes
      scroll_delta : Int8
    end
  end

  class Node < VFS::Node
    getter fs : VFS::FS, first_child

    def initialize(@fs : FS)
      @first_child = RawNode.new(fs)
    end

    def each_child(&block)
      node = first_child
      while !node.nil?
        yield node.not_nil!
        node = node.next_node
      end
    end

    def open(path : Slice, process : Multiprocessing::Process? = nil) : VFS::Node?
      each_child do |node|
        if node.name == path
          return node
        end
      end
    end

    def read(slice : Slice, offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      x, y, _ = fs.mouse.flush

      writer = SliceWriter.new(slice)
      writer << x
      writer << ','
      writer << y
      writer << '\n'

      writer.offset
    end
  end

  class RawNode < VFS::Node
    getter fs : VFS::FS

    def initialize(@fs : FS)
    end

    def name
      "raw"
    end

    def read(slice : Slice, offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      x, y, attr_byte, scroll_delta = fs.mouse.flush

      packet = uninitialized Data::MousePacket
      packet.x = x
      packet.y = y
      packet.attributes = Data::MouseAttributes.new(attr_byte.value.to_u32 & 0x3)
      packet.scroll_delta = scroll_delta
      size = Math.min slice.size, sizeof(Data::MousePacket)
      memcpy(slice.to_unsafe, pointerof(packet).as(UInt8*), size.to_usize)

      size
    end

    def available?(process : Multiprocessing::Process) : Bool
      fs.mouse.available
    end
  end

  class FS < VFS::FS
    getter! root : VFS::Node
    getter mouse

    def name : String
      "mouse"
    end

    def initialize(@mouse : Mouse)
      @root = Node.new self
      @mouse.mousefs = self
    end
  end
end
