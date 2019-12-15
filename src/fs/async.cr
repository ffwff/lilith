class VFSMessage
  @next_msg = Atomic(VFSMessage?).new(nil)
  property next_msg

  getter process

  @offset = 0
  getter offset

  # TODO: file offset

  getter vfs_node

  def slice_size
    @slice.not_nil!.size
  end

  getter udata

  getter type

  enum Type
    Read
    Write
    Spawn
  end

  def initialize(@type : Type,
                 @slice : Slice(UInt8)?,
                 @process : Multiprocessing::Process?,
                 @fd : FileDescriptor?,
                 @vfs_node : VFSNode)
  end

  def initialize(@udata : Multiprocessing::Process::UserData?,
                 @vfs_node : VFSNode,
                 @process : Multiprocessing::Process? = nil,
                 @type = VFSMessage::Type::Spawn)
  end

  def buffering
    return VFSNode::Buffering::Unbuffered if @fd.nil?
    @fd.not_nil!.buffering
  end

  def file_offset
    if @fd.nil?
      0
    else
      @fd.not_nil!.offset
    end
  end

  def consume
    if @offset > 0
      @process.not_nil!.write_to_virtual(@slice.not_nil!.to_unsafe + @offset, 0u8)
      @offset -= 1
    end
  end

  private def finish
    @offset = slice_size
  end

  def finished?
    offset >= slice_size
  end

  def read(&block)
    remaining = slice_size
    # Serial.print "rem:" , remaining, '\n'
    # offset of byte to be written in page (0 -> 0x1000)
    pg_offset = @slice.not_nil!.to_unsafe.address & 0xFFF
    # virtual page range
    virt_pg_addr = Paging.aligned_floor(@slice.not_nil!.to_unsafe.address)
    virt_pg_end = Paging.aligned(@slice.not_nil!.to_unsafe.address + remaining)
    # Serial.print "paddr:" , Pointer(Void).new(virt_pg_addr), " ", Pointer(Void).new(virt_pg_end), '\n'
    while virt_pg_addr < virt_pg_end
      # physical address of the current page
      phys_pg_addr = @process.not_nil!.physical_page_for_address(virt_pg_addr)
      # Serial.print phys_pg_addr, '\n'
      if phys_pg_addr.nil?
        # Serial.print "unable to read\n"
        finish
        return
      end
      phys_pg_addr = phys_pg_addr.not_nil!
      while remaining > 0 && pg_offset < 0x1000
        # Serial.print phys_pg_addr + pg_offset, '\n'
        yield phys_pg_addr[pg_offset]
        remaining -= 1
        pg_offset += 1
      end
      pg_offset = 0
      virt_pg_addr += 0x1000
    end
  end

  def respond(buf : Slice(UInt8))
    pslice = @slice.not_nil!
    process = @process.not_nil!
    remaining = Math.min(buf.size, slice_size - @offset)
    # virtual addresses
    page_start_u = pslice.to_unsafe.address + @offset
    page_start = Paging.aligned_floor(page_start_u)
    page_end = Paging.aligned(pslice.to_unsafe.address + pslice.size)
    p_offset = page_start_u & 0xFFF
    # loop!
    b_offset = 0
    while page_start < page_end && remaining > 0
      copy_sz = Math.min(0x1000 - p_offset, remaining)
      if physical_page = process.physical_page_for_address(page_start)
        memcpy(physical_page + p_offset, buf.to_unsafe + b_offset, copy_sz.to_usize)
      else
        finish
        return @offset
      end
      remaining -= copy_sz
      b_offset += copy_sz
      @offset += copy_sz
      p_offset = 0
      page_start += 0x1000
    end
    @offset
  end

  def respond(ch : UInt8)
    unless finished?
      unless @process.not_nil!.write_to_virtual(@slice.not_nil!.to_unsafe + @offset, ch.to_u8)
        finish
        return
      end
      @offset += 1
    end
  end

  def unawait
    return if @process.not_nil!.sched_data.status == Multiprocessing::Scheduler::ProcessData::Status::Normal
    @process.not_nil!.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::Normal
    if @fd
      @fd.not_nil!.offset += @offset
    end
    @process.not_nil!.frame.not_nil!.to_unsafe.value.rax = @offset
  end

  def unawait(retval)
    return if @process.not_nil!.sched_data.status == Multiprocessing::Scheduler::ProcessData::Status::Normal
    @process.not_nil!.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::Normal
    @process.not_nil!.frame.not_nil!.to_unsafe.value.rax = retval
  end
end

class VFSQueue
  @first_msg = Atomic(VFSMessage?).new(nil)
  @last_msg = Atomic(VFSMessage?).new(nil)

  def initialize(@wake_process : Multiprocessing::Process? = nil)
  end

  def empty?
    @first_msg.get.nil?
  end

  def enqueue(msg : VFSMessage)
    if @first_msg.get.nil?
      @first_msg.set(msg)
      @last_msg.set(msg)
      msg.next_msg.set(nil)
    else
      @last_msg.get.not_nil!.next_msg.set(msg)
      @last_msg.set(msg)
    end
    if @wake_process
      @wake_process.not_nil!.sched_data.status =
        Multiprocessing::Scheduler::ProcessData::Status::Normal
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
