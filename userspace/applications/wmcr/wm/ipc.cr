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
      x, y, width, height : Int32
    end

    RESPONSE_ID = 2
    @[Packed]
    struct Response
      header : Header
      retval : Int32
    end
  end

  alias Message = Data::WindowCreate | Data::Response

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

  macro payload_size(t)
    sizeof({{ t }}) - sizeof(IPC::Data::Header)
  end

  macro payload_bytes(msg)
    Bytes.new(Pointer(UInt8).new(pointerof({{ msg }}).address + sizeof(IPC::Data::Header)),
              IPC.payload_size(typeof({{ msg }})))
  end

  # Creates a test message
  def test_message
    msg = uninitialized UInt8[sizeof(Data::Header)]
    msg.to_unsafe.as(Data::Header*)
      .value = create_header 0, Data::TEST_MESSAGE_ID
    msg
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

  # Creates response message
  def response_message(retval)
    msg = uninitialized UInt8[sizeof(Data::Response)]
    rep = msg.to_unsafe.as(Data::Response*)
    rep.value.header = create_header(
      payload_size(Data::Response),
      Data::RESPONSE_ID)
    rep.value.retval = retval
    msg
  end

end
