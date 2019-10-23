module Wm::IPC
  extend self

  lib Data
    MAGIC = "wm-ipc"
    @[Packed]
    struct Header
      magic : UInt8[6] # wm-ipc
      length : UInt8
      type : UInt8
    end
  end

  def valid_msg?(msg : Bytes)
    return false if msg.size < sizeof(Data::Header)
    header = msg.to_unsafe.as(Data::Header*)
    if LibC.strncmp(header.value.magic.to_unsafe,
                    Data::MAGIC.to_unsafe,
                    Data::MAGIC.bytesize) != 0
      return false
    end
    sizeof(Data::Header) + header.value.length <= msg.size
  end

  def create_header(length, type)
    header = Data::Header.new
    LibC.strncpy(header.magic.to_unsafe,
                 Data::MAGIC.to_unsafe,
                 Data::MAGIC.bytesize)
    header.length = length
    header.type = type
    header
  end

  def header_part(msg : Bytes)
    msg.to_unsafe.as(Data::Header*)
  end

  def test_message
    msg = uninitialized UInt8[sizeof(Data::Header)]
    msg.to_unsafe.as(Data::Header*).value = create_header 0, 0
    msg
  end

end
