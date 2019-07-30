require "../../fs/kbdfs.cr"

KEYBOARD_MAP = StaticArray[
  '\0', '\0', '1', '2', '3', '4', '5', '6', '7', '8', # 9
  '9', '0', '-', '=', '\b',                         # Backspace
  '\t',                                             # Tab
  'q', 'w', 'e', 'r',                               # 19
  't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',     # Enter key
  '\0',                                             # 29   - Control
  'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', # 39
  '\'', '`', '\0',                                  # Left shift
  '\\', 'z', 'x', 'c', 'v', 'b', 'n',               # 49
  'm', ',', '.', '/', '\0',                         # Right shift
  '*',
  '\0', # Left Alt
  ' ',  # Space bar
  '\0', # Caps lock
  '\0', # 59 - F1 key ... >
  '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0',
  '\0', # < ... F1'\0'
  '\0', # 69 - Num lock
  '\0', # Scroll Lock
  '7', # 0x47
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

class Keyboard < Gc
  @[Flags]
  enum Modifiers
    None   = 0x0
    ShiftL = 0x1
    ShiftR = 0x2
  end

  @current_keycode : Char? = nil
  getter current_keycode

  @modifiers = Modifiers::None

  @kbdfs : KbdFS? = nil
  property kbdfs

  def initialize
    Idt.register_irq 1, ->callback
    # use scan code set 1
    X86.outb 0xF0, 1
    # enable scanning
    X86.outb 0xF4, 0
  end

  def callback
    keycode = X86.inb(0x60)
    case keycode
    when 0x2A # left shift pressed
      @modifiers |= Modifiers::ShiftL
    when 0x36 # right shift pressed
      @modifiers |= Modifiers::ShiftR
    when 0xAA # left shift released
      @modifiers &= ~Modifiers::ShiftL
    when 0xB6 # right shift released
      @modifiers &= ~Modifiers::ShiftR
    else
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
  end
end