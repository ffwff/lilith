require "../../fs/impl/kbdfs.cr"

KEYBOARD_MAP = StaticArray[
  '\0', '\0', '1', '2', '3', '4', '5', '6', '7', '8', # 9
  '9', '0', '-', '=', '\b',                           # Backspace
  '\t',                                               # Tab
  'q', 'w', 'e', 'r',                                 # 19
  't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',       # Enter key
  '\0',                                               # 29   - Control
  'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';',   # 39
  '\'', '`', '\0',                                    # Left shift
  '\\', 'z', 'x', 'c', 'v', 'b', 'n',                 # 49
  'm', ',', '.', '/', '\0',                           # Right shift
  '*',
  '\0', # Left Alt
  ' ',  # Space bar
  '\0', # Caps lock
  '\0', # 59 - F1 key ... >
  '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0',
  '\0', # < ... F1'\0'
  '\0', # 69 - Num lock
  '\0', # Scroll Lock
  '7',  # 0x47
  '8',
  '9',
  '-',
  '4', # 0x4C
  '5',
  '6',
  '+',
  '1', # 0x50
  '2',
  '3',
  '0',
# All other keys are undefined
]

KEYBOARD_MAP_SHIFT = StaticArray[
  nil, nil, '!', '@', '#', '$', '%', '^', '&', '*',
  '(', ')', '_', '+', nil,
  nil,
  'Q', 'W', 'E', 'R',
  'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', nil,
  nil,
  'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':',
  '"', '`', '\0',
  '|', 'Z', 'X', 'C', 'V', 'B', 'N',
  'M', '<', '>', '?',
]

class Keyboard
  @[Flags]
  enum Modifiers : Int32
    ShiftL = 1 << 0
    ShiftR = 1 << 1
    CtrlL  = 1 << 3
    CtrlR  = 1 << 4
  end

  enum SpecialKeys
    UpArrow
    DownArrow
    LeftArrow
    RightArrow
    Delete
  end

  @current_keycode : Char? = nil
  getter current_keycode

  @modifiers = Modifiers::None
  getter modifiers

  @kbdfs : KbdFS? = nil
  property kbdfs

  def initialize
    Idt.register_irq 1, ->callback
  end

  @last_e0 = false
  @last_f0 = false

  def callback
    keycode = PS2.read
    # Serial.print "kc: ", keycode,'\n'
    case keycode
    when 0x2A # left shift pressed
      @modifiers |= Modifiers::ShiftL
    when 0x36 # right shift pressed
      @modifiers |= Modifiers::ShiftR
    when 0xAA # left shift released
      @modifiers &= ~Modifiers::ShiftL
    when 0xB6 # right shift released
      @modifiers &= ~Modifiers::ShiftR
    when 0x1D # control pressed
      if @last_e0
        @modifiers |= Modifiers::CtrlR
      else
        @modifiers |= Modifiers::CtrlL
      end
      @last_e0 = false
    when 0x9D # control released
      if @last_e0
        @modifiers &= ~Modifiers::CtrlR
      else
        @modifiers &= ~Modifiers::CtrlL
      end
      @last_e0 = false
    when 0xE0 # left/right control modifier
      @last_e0 = true
    when 0xF0
      @last_f0 = true
      return
    else
      if @last_e0
        case keycode
        when 0x48 # up
          @kbdfs.not_nil!.on_key SpecialKeys::UpArrow
        when 0x50 # down
          @kbdfs.not_nil!.on_key SpecialKeys::DownArrow
        when 0x4b # left
          @kbdfs.not_nil!.on_key SpecialKeys::LeftArrow
        when 0x4d # right
          @kbdfs.not_nil!.on_key SpecialKeys::RightArrow
        when 0x53 # delete
          @kbdfs.not_nil!.on_key SpecialKeys::Delete
        end
        @last_e0 = false
        @last_f0 = false
        return
      end
      keycode = keycode.to_i8
      if keycode > 0
        if @modifiers.includes?(Modifiers::ShiftL) ||
           @modifiers.includes?(Modifiers::ShiftR)
          kc = KEYBOARD_MAP_SHIFT[keycode]? || KEYBOARD_MAP[keycode]?
        else
          kc = KEYBOARD_MAP[keycode]?
        end
        if !@kbdfs.nil? && !kc.nil?
          @kbdfs.not_nil!.on_key kc
        end
      end
    end
    @last_f0 = false
  end
end
