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

    HEADER_SIZE = 8

    TEST_MESSAGE_ID = 0

    WINDOW_CREATE_ID = 1
    @[Packed]
    struct WindowCreate
      header : Header
      x, y, width, height : Int32
      flags : WindowFlags
    end

    @[Flags]
    enum WindowFlags : Int32
      Background = 1 << 0
      Alpha      = 1 << 1
    end

    RESPONSE_ID = 2
    @[Packed]
    struct Response
      header : Header
      retval : Int32
    end

    KBD_EVENT_ID = 3
    @[Packed]
    struct KeyboardEvent
      header : Header
      ch : Int32
      modifiers : KeyboardEventModifiers
    end

    @[Flags]
    enum KeyboardEventModifiers : Int32
      ShiftL = 1 << 0
      ShiftR = 1 << 1
      CtrlL  = 1 << 2
      CtrlR  = 1 << 3
      GuiL   = 1 << 4
    end

    MOUSE_EVENT_ID = 4
    @[Packed]
    struct MouseEvent
      header : Header
      x, y : Int32
      modifiers : MouseEventModifiers
      scroll_delta : Int32
    end

    @[Flags]
    enum MouseEventModifiers : UInt32
      LeftButton   = 1 << 0
      RightButton  = 1 << 1
      MiddleButton = 1 << 2
    end

    MOVE_REQ_ID = 5
    @[Packed]
    struct MoveRequest
      header : Header
      x, y : Int32
      relative : UInt8
    end

    REFOCUS_ID = 6
    @[Packed]
    struct RefocusEvent
      header : Header
      wid : Int32
      focused : UInt8
    end

    QUERY_ID = 7
    @[Packed]
    struct Query
      header : Header
      type : QueryType
    end

    enum QueryType : Int32
      ScreenDim = 0
    end

    DYN_RESPONSE_ID = 8

    REDRAW_REQ_ID = 9
    @[Packed]
    struct RedrawRequest
      header : Header
      x, y, width, height : Int32
    end

    WINDOW_CLOSE_ID = 10

    WINDOW_UPDATE_ID = 11
    @[Packed]
    struct WindowUpdate
      header : Header
      x, y, width, height : Int32
    end
  end

  struct DynamicResponse
    getter buffer

    def initialize(@buffer : Bytes)
    end
  end

  alias Message = Data::WindowCreate |
                  Data::Response |
                  Data::KeyboardEvent |
                  Data::MouseEvent |
                  Data::MoveRequest |
                  Data::RefocusEvent |
                  Data::Query |
                  Data::RedrawRequest |
                  Data::WindowUpdate |
                  DynamicResponse

  # Checks if bytes represents a valid IPC message
  def valid_msg?(msg : Bytes) : Bool
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

  # Creates a window close message
  def window_close_message
    msg = uninitialized UInt8[sizeof(Data::Header)]
    msg.to_unsafe.as(Data::Header*)
      .value = create_header 0, Data::WINDOW_CLOSE_ID
    msg
  end

  # Creates window create message
  def window_create_message(x, y, width, height, flags = Data::WindowFlags::None)
    msg = uninitialized UInt8[sizeof(Data::WindowCreate)]
    wc = msg.to_unsafe.as(Data::WindowCreate*)
    wc.value.header = create_header(
      payload_size(Data::WindowCreate),
      Data::WINDOW_CREATE_ID)
    wc.value.x = x
    wc.value.y = y
    wc.value.width = width
    wc.value.height = height
    wc.value.flags = flags
    msg
  end

  # Creates window update message
  def window_update_message(x, y, width, height)
    msg = uninitialized UInt8[sizeof(Data::WindowUpdate)]
    wc = msg.to_unsafe.as(Data::WindowUpdate*)
    wc.value.header = create_header(
      payload_size(Data::WindowUpdate),
      Data::WINDOW_UPDATE_ID)
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

  # Creates keyboard event message
  def kbd_event_message(ch, modifiers)
    msg = uninitialized UInt8[sizeof(Data::KeyboardEvent)]
    rep = msg.to_unsafe.as(Data::KeyboardEvent*)
    rep.value.header = create_header(
      payload_size(Data::KeyboardEvent),
      Data::KBD_EVENT_ID)
    rep.value.ch = ch
    rep.value.modifiers = modifiers
    msg
  end

  # Creates mouse event message
  def mouse_event_message(x, y, modifiers, scroll_delta)
    msg = uninitialized UInt8[sizeof(Data::MouseEvent)]
    rep = msg.to_unsafe.as(Data::MouseEvent*)
    rep.value.header = create_header(
      payload_size(Data::MouseEvent),
      Data::MOUSE_EVENT_ID)
    rep.value.x = x
    rep.value.y = y
    rep.value.modifiers = modifiers
    rep.value.scroll_delta = scroll_delta
    msg
  end

  # Creates move request message
  def move_request_message(x, y, relative = true)
    msg = uninitialized UInt8[sizeof(Data::MoveRequest)]
    rep = msg.to_unsafe.as(Data::MoveRequest*)
    rep.value.header = create_header(
      payload_size(Data::MoveRequest),
      Data::MOVE_REQ_ID)
    rep.value.x = x
    rep.value.y = y
    rep.value.relative = relative ? 1 : 0
    msg
  end

  # Creates focus change message
  def refocus_event_message(wid, focused)
    msg = uninitialized UInt8[sizeof(Data::RefocusEvent)]
    rep = msg.to_unsafe.as(Data::RefocusEvent*)
    rep.value.header = create_header(
      payload_size(Data::RefocusEvent),
      Data::REFOCUS_ID)
    rep.value.wid = wid
    rep.value.focused = focused
    msg
  end

  # Creates query message
  def query_message(type)
    msg = uninitialized UInt8[sizeof(Data::Query)]
    rep = msg.to_unsafe.as(Data::Query*)
    rep.value.header = create_header(
      payload_size(Data::Query),
      Data::QUERY_ID)
    rep.value.type = type
    msg
  end

  # Creates redraw request message
  def redraw_request_message(x, y, width, height)
    msg = uninitialized UInt8[sizeof(Data::RedrawRequest)]
    rep = msg.to_unsafe.as(Data::RedrawRequest*)
    rep.value.header = create_header(
      payload_size(Data::RedrawRequest),
      Data::REDRAW_REQ_ID)
    rep.value.x = x
    rep.value.y = y
    rep.value.width = width
    rep.value.height = height
    msg
  end

  # Creates a dynamically sized response message
  struct DynamicWriter(N)
    def self.write(&block)
      {% if N > 0 %}
        msg = uninitialized UInt8[{{ N + 8 }}]
        header = msg.to_unsafe.as(Data::Header*)
        header.value = IPC.create_header(
          {{ N }},
          Data::DYN_RESPONSE_ID)
        yield msg.to_slice + sizeof(Data::Header)
        msg
      {% end %}
    end
  end
end
