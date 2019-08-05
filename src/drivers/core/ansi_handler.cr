class AnsiHandler

  enum State : Int32
    Default     = 0
    EscapeBegin = 0x69
    Csi         = 2
  end

  enum CsiSequenceType
    EraseInLine
    MoveCursor
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
  end

  def parse(ch)
    case @state
    when State::Default
      if ch == 0x1B
        @state = State::EscapeBegin
        return nil
      else
        return ch
      end
    when State::EscapeBegin
      if ch == '['.ord.to_u8
        @state = State::Csi
        return nil
      else
        return reset
      end
    when State::Csi
      if digit?(ch)
        if @arg_n.nil?
          @arg_n = to_digit(ch).to_u16
        else
          @arg_n = @arg_n.not_nil! * 10 + to_digit(ch).to_u16
        end
      elsif ch == 'H'.ord.to_u8
        if @arg_n.nil? && @arg_m.nil?
          seq = CsiSequence.new(CsiSequenceType::MoveCursor, 0, 0)
        else
          seq = CsiSequence.new(CsiSequenceType::MoveCursor, @arg_n, @arg_m)
        end
        reset
        return seq
      elsif !@arg_n.nil? && ch == 'K'.ord.to_u8
        seq = CsiSequence.new(CsiSequenceType::EraseInLine, @arg_n)
        reset
        return seq
      else
        return reset
      end
    end
  end

end