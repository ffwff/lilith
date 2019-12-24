class SerialFS::Node < VFS::Node
  getter fs : VFS::FS

  def initialize(@fs : SerialFS::FS)
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

class SerialFS::FS < VFS::FS
  getter! root : VFS::Node

  def name : String
    "serial"
  end

  def initialize
    @root = SerialFS::Node.new self
  end
end
