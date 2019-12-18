private class SerialFSNode < VFS::Node
  getter fs : VFS::FS

  def initialize(@fs : SerialFS)
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    0
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    slice.each do |ch|
      Serial.putc ch
    end
    slice.size
  end
end

class SerialFS < VFS::FS
  getter! root : VFS::Node

  def name : String
    "serial"
  end

  def initialize
    @root = SerialFSNode.new self
  end
end
