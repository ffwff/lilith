class AnsiHandler

  enum State : Int32
    Default
    EscapeBegin
    Csi
  end

  enum CsiSequenceType
    EraseInLine
    MoveCursor
    ShowCursor
    HideCursor
  end

  struct CsiSequence
    getter type, arg_n, arg_m
    def initialize(@type : CsiSequenceType,
                   @arg_n : UInt16? = nil,
                   @arg_m : UInt16? = nil)
    end
  end

  @state = State::Default
  getter state
  @arg_n : UInt16? = nil
  @arg_m : UInt16? = nil
  @csi_m = false
  @csi_priv = false

  private def digit?(ch)
    ch >= '0'.ord.to_u8 && ch <= '9'.ord.to_u8
  end

  private def to_digit(ch)
    ch - '0'.ord.to_u8
  end

  def reset
    @state = State::Default
    @arg_n = nil
    @arg_m = nil
    @csi_m = false
    @csi_priv = false
  end

  def parse(ch)
    case @state
    when State::Default
      if ch == 0x1B
        @state = State::EscapeBegin
      else
        ch
      end
    when State::EscapeBegin
      if ch == '['.ord.to_u8
        @state = State::Csi
      else
        reset
      end
    when State::Csi
      if digit?(ch)
        if @csi_m
          if @arg_m.nil?
            @arg_m = to_digit(ch).to_u16
          else
            @arg_m = @arg_m.not_nil! * 10 + to_digit(ch).to_u16
          end
        else
          if @arg_n.nil?
            @arg_n = to_digit(ch).to_u16
          else
            @arg_n = @arg_n.not_nil! * 10 + to_digit(ch).to_u16
          end
        end
      elsif ch == ';'.ord.to_u8
        if @arg_n.nil?
          return reset
        end
        @csi_m = true
      elsif ch == '?'.ord.to_u8
        @csi_priv = true
      elsif ch == 'H'.ord.to_u8
        # move cursor
        if @arg_n.nil?
          @arg_n = 0u16
        end
        if @arg_m.nil?
          @arg_m = 0u16
        end
        seq = CsiSequence.new CsiSequenceType::MoveCursor, @arg_n, @arg_m
        reset
        seq
      elsif ch == 'h'.ord.to_u8
        # show cursor
        if @csi_priv
          if @arg_n == 25
            seq = CsiSequence.new CsiSequenceType::ShowCursor
          end
        end
        reset
        seq
      elsif ch == 'l'.ord.to_u8
        # hide cursor
        if @csi_priv
          if @arg_n == 25
            seq = CsiSequence.new CsiSequenceType::HideCursor
          end
        end
        reset
        seq
      elsif ch == 'm'.ord.to_u8
        # SGR
        Serial.puts "unhandled sgr: ", @arg_n, '\n'
        reset
      elsif !@arg_n.nil? && ch == 'K'.ord.to_u8
        seq = CsiSequence.new CsiSequenceType::EraseInLine, @arg_n
        reset
        seq
      else
        reset
      end
    end
  end

end