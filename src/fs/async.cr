class VFSMessage
  @next_msg = Atomic(VFSMessage?).new(nil)
  property next_msg

  getter process

  @offset = 0
  getter offset

  # TODO: file offset

  @buffering = VFSNode::Buffering::Unbuffered
  getter buffering

  getter vfs_node

  def slice_size
    @slice.size
  end

  enum Type
    Read
    Write
  end

  def initialize(@type : Type,
                 @slice : Slice(UInt8),
                 @process : Multiprocessing::Process,
                 @buffering,
                 @vfs_node : VFSNode)
  end

  def finished?
    offset == @slice.size
  end

  def respond(buf)
    size = min(buf.size, @slice.size - @offset)
    if size > 0
      size.times do |i|
        @process.write_to_virtual(@slice.to_unsafe + @offset, buf[i])
        @offset += 1
      end
    end
  end

  def respond(ch)
    unless finished?
      @process.write_to_virtual(@slice.to_unsafe + @offset, ch.to_u8)
      @offset += 1
    end
  end

  def unawait
    @process.status = Multiprocessing::Process::Status::Unwait
    @process.frame.value.rax = @offset
  end
end

class VFSQueue
  @first_msg = Atomic(VFSMessage?).new(nil)
  @last_msg  = Atomic(VFSMessage?).new(nil)

  def enqueue(msg : VFSMessage)
    if @first_msg.get.nil?
      @first_msg.set(msg)
      @last_msg.set(msg)
      msg.next_msg.set(nil)
    else
      @last_msg.get.not_nil!.next_msg.set(msg)
      @last_msg.set(msg)
    end
  end

  def dequeue
    unless (msg = @first_msg.get).nil?
      @first_msg.set(msg.not_nil!.next_msg.get)
      msg
    else
      nil
    end
  end

  def keep_if(&block : VFSMessage -> _)
    prev = nil
    cur = @first_msg
    until (c = cur.get).nil?
      c = c.not_nil!
      if yield c
        prev = c
      else
        if prev.nil?
          @first_msg.set(c.next_msg.get)
        else
          prev.next_msg.set(nil)
        end
      end
      cur = c.next_msg
    end
  end
end
