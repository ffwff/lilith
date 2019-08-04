class VFSReadMessage
  @next_msg : VFSReadMessage? = nil
  property next_msg

  getter process

  @offset = 0
  getter offset

  @buffering = VFSNode::Buffering::Unbuffered
  getter buffering

  def initialize(@slice : Slice(UInt8),
                 @process : Multiprocessing::Process,
                 @buffering)
  end

  def finished?
    offset == @slice.size
  end

  def respond(buf)
    size = min(buf.size, @slice.size - @offset)
    if size > 0
      size.times do |i|
        @slice[@offset] = buf[i]
        @offset += 1
      end
    end
  end

  def respond(ch)
    unless finished?
      @slice[@offset] = ch.to_u8
      @offset += 1
    end
  end
end

class VFSReadQueue
  @first_msg : VFSReadMessage? = nil
  @last_msg : VFSReadMessage? = nil

  def pop
    msg = @first_msg
    @first_msg = @first_msg.not_nil!.next_msg
    msg
  end

  def push(msg : VFSReadMessage)
    if @first_msg.nil?
      @first_msg = msg
      @last_msg = msg
      msg.next_msg = nil
    else
      @last_msg.not_nil!.next_msg = msg
      @last_msg = msg
    end
  end

  def keep_if(&block : VFSReadMessage -> _)
    prev = nil
    cur = @first_msg
    while !cur.nil?
      c = cur.not_nil!
      if yield(c)
        prev = cur
      else
        if prev.nil?
          @first_msg = c.next_msg
        else
          prev.next_msg = nil
        end
      end
      cur = c.next_msg
    end
  end
end
