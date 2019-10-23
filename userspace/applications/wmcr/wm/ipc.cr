module Wm

  lib IPC
    MAGIC = "wm-ipc"
    struct Header
      magic : UInt8[6] # wm-ipc
      length : UInt8
      type : UInt8
    end
  end

  def create_ipc_header(length, type)
    header = IPC::Header.new
    LibC.strncpy(header.magic.as(UInt8*),
                 IPC::MAGIC.bytesize,
                 IPC::MAGIC.to_unsafe)
    header.length = length
    header.type = type
    header
  end

end
