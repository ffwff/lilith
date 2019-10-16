private class SerialFSNode < VFSNode
  getter fs : VFS

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

class SerialFS < VFS
  getter! name : GcString, root : VFSNode

  def initialize
    @name = GcString.new "serial"
    @root = SerialFSNode.new self
  end
end
