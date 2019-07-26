class VFSReadMessage < Gc
  @next_msg : VFSReadMessage | Nil = nil
  property next_msg

  getter slice, process

  def initialize(@slice : Slice(UInt8), @process : Multiprocessing::Process)
  end
end

class VFSReadQueue < Gc
  @first_msg : VFSReadMessage | Nil = nil
  @last_msg : VFSReadMessage | Nil = nil

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
