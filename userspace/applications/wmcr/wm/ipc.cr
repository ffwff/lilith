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

    TEST_MESSAGE_ID = 0

    WINDOW_CREATE_ID = 1
    @[Packed]
    struct WindowCreate
      header : Header
      x, y, width, height : UInt32
    end
  end

  # Checks if bytes represents a valid IPC message
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

  # Creates IPC header
  def create_header(length, type)
    header = Data::Header.new
    LibC.strncpy(header.magic.to_unsafe,
                 Data::MAGIC.to_unsafe,
                 Data::MAGIC.bytesize)
    header.length = length
    header.type = type
    header
  end

  # Gets a pointer to the header of a byte stream
  def header_part(msg : Bytes)
    msg.to_unsafe.as(Data::Header*)
  end

  # Gets a pointer to the payload of a byte stream
  macro payload_part(t, msg)
    ({{ msg }}.to_unsafe).as({{ t }}*).value
  end

  # Creates a test message
  def test_message
    msg = uninitialized UInt8[sizeof(Data::Header)]
    msg.to_unsafe.as(Data::Header*)
      .value = create_header 0, Data::TEST_MESSAGE_ID
    msg
  end

  private macro payload_size(t)
    sizeof({{ t }}) - sizeof(Data::Header)
  end

  # Creates window create message
  def window_create_message(x, y, width, height)
    msg = uninitialized UInt8[sizeof(Data::WindowCreate)]
    wc = msg.to_unsafe.as(Data::WindowCreate*)
    wc.value.header = create_header(
      payload_size(Data::WindowCreate),
      Data::WINDOW_CREATE_ID)
    wc.value.x = x
    wc.value.y = y
    wc.value.width = width
    wc.value.height = height
    msg
  end

end
