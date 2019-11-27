private lib Kernel
  fun ksyscall_switch(frame : Idt::Data::Registers*) : NoReturn
end

module Multiprocessing::Scheduler
  extend self

  NORMAL_TIME_SLICE = 10u64 # 1ms

  class ProcessData
    @next_data : ProcessData? = nil
    @prev_data : ProcessData? = nil
    property next_data, prev_data

    getter process

    # status
    enum Status
      Normal
      Running
      WaitIo
      WaitProcess
      WaitFd
      Sleep
      Removed
    end

    private def wait_status?(status)
      case status
      when Status::WaitIo
        true
      when Status::WaitProcess
        true
      when Status::WaitFd
        true
      when Status::Sleep
        true
      else
        false
      end
    end

    @status = Status::Normal
    getter status

    def status=(s)
      if s != Status::Removed
        if !wait_status?(@status) && wait_status?(s)
          # transition to active state
          Scheduler.move_to_io_queue self
        elsif wait_status?(@status) && !wait_status?(s)
          # transition to wait state
          Scheduler.move_to_cpu_queue self
        end
      end
      @status = s
    end

    # which queue we're in
    @queue_id = -1
    property queue_id

    # time for process to run in microseconds
    @time_slice = NORMAL_TIME_SLICE
    property time_slice

    def initialize(@queue_id, @process : Multiprocessing::Process)
    end

    def can_switch? : Bool
      process = self.process
      # Serial.print "next_process: ", process.name, '\n'
      case @status
      when ProcessData::Status::Normal
        true
      when ProcessData::Status::Removed
        false
      when ProcessData::Status::WaitIo
        false
      when ProcessData::Status::WaitProcess
        wait_object = process.udata.wait_object
        case wait_object
        when Process
          if wait_object.as(Process).removed?
            process.unawait
            true
          else
            false
          end
        else
          process.unawait
          true
        end
      when ProcessData::Status::WaitFd
        wait_object = process.udata.wait_object
        case wait_object
        when Array(FileDescriptor)
          if process.udata.wait_end != 0 && process.udata.wait_end <= Time.usecs_since_boot
            process.frame.not_nil!.to_unsafe.value.rax = 0
            process.unawait
            return true
          end
          fds = wait_object.as(Array(FileDescriptor))
          fds.each do |fd|
            fd = fd.not_nil!
            if fd.node.not_nil!.available? process
              process.frame.not_nil!.to_unsafe.value.rax = fd.idx
              process.unawait
              return true
            end
          end
          false
        when FileDescriptor
          if process.udata.wait_end != 0 && process.udata.wait_end <= Time.usecs_since_boot
            process.frame.not_nil!.to_unsafe.value.rax = 0
            process.unawait
            return true
          end
          fd = wait_object.as(FileDescriptor)
          if fd.node.not_nil!.available? process
            process.frame.not_nil!.to_unsafe.value.rax = fd.idx
            process.unawait
            true
          else
            false
          end
        else
          process.unawait
          true
        end
      when ProcessData::Status::Sleep
        if process.udata.wait_end <= Time.usecs_since_boot
          process.unawait
          true
        else
          false
        end
      else
        false
      end
    end
  end

  struct Queue
    @first_data : ProcessData? = nil
    @last_data : ProcessData? = nil
    property first_data, last_data

    getter queue_id

    def initialize(@queue_id : Int32)
    end

    def append_process_data(data : ProcessData)
      if data.next_data || data.prev_data
        panic "Scheduler::Queue: already in list!"
      end
      data.queue_id = @queue_id
      if @first_data.nil?
        @first_data = @last_data = data
      else
        @last_data.not_nil!.next_data = data
        data.prev_data = @last_data
        @last_data = data
      end
    end

    def remove_process_data(data : ProcessData)
      return false if data.queue_id != @queue_id
      if @first_data == data
        @first_data = data.next_data
      end
      if @last_data == data
        @last_data = data.prev_data
      end
      if data.next_data
        data.next_data.not_nil!.prev_data = data.prev_data
      end
      if data.prev_data
        data.prev_data.not_nil!.next_data = data.next_data
      end
      data.prev_data = nil
      data.next_data = nil
      true
    end

    def next_process(current_process : Process? = nil) : Process?
      return nil if @first_data.nil?
      if current_process.nil?
        sched_data = @first_data.not_nil!
        cur = sched_data
      else
        sched_data = current_process.not_nil!.sched_data
        cur = sched_data.next_data
      end
      # look from middle to end
      while !cur.nil? && !cur.not_nil!.can_switch?
        cur = cur.next_data
      end
      # look from start to middle
      if cur.nil?
        cur = @first_data
        while !cur.nil? && !cur.not_nil!.can_switch?
          cur = cur.next_data
          break if cur == sched_data.prev_data
        end
        if cur && !cur.not_nil!.can_switch?
          cur = nil
        end
      end
      unless cur.nil?
        panic "status != Status::Normal" if cur.status != ProcessData::Status::Normal
        cur.process
      else
        nil
      end
    end

    def to_s(io)
      cur = @first_data
      while !cur.nil?
        io.print "- ", cur.process.name, ": ", cur.status, "(", cur.queue_id, ")\n"
        cur = cur.next_data
      end
    end
  end

  @@cpu_queue = Queue.new 0
  @@io_queue = Queue.new 1

  def append_process(process : Process)
    sched_data = ProcessData.new(@@cpu_queue.queue_id, process)
    @@cpu_queue.append_process_data sched_data
    sched_data
  end

  def remove_process(process : Process)
    sched_data = process.sched_data
    case sched_data.queue_id
    when @@cpu_queue.queue_id
      @@cpu_queue.remove_process_data sched_data
    when @@io_queue.queue_id
      @@io_queue.remove_process_data sched_data
    else
      panic "unknown queue_id: ", sched_data.queue_id
    end
  end

  def debug
    Serial.print "cpu:\n"
    @@cpu_queue.to_s Serial
    Serial.print "io:\n"
    @@io_queue.to_s Serial
    Serial.print "---\n"
  end

  protected def move_to_cpu_queue(data : ProcessData)
    unless @@io_queue.remove_process_data data
      panic "data must be in io_queue"
    end
    @@cpu_queue.append_process_data data
  end

  protected def move_to_io_queue(data : ProcessData)
    unless @@cpu_queue.remove_process_data data
      panic "data must be in cpu_queue"
    end
    @@io_queue.append_process_data data
  end

  private def get_next_process
    next_process = if (process = @@io_queue.next_process)
      if process == @@current_process
        # try to prevent resource starvation by getting another in the queue
        @@cpu_queue.next_process
      else
        process
      end
    else
      @@cpu_queue.next_process(@@current_process)
    end
    next_process
  end

  @@current_process : Multiprocessing::Process? = nil

  def current_process
    @@current_process
  end

  def current_process=(@@current_process)
  end

  def context_switch_to_process(process : Multiprocessing::Process)
    if process.frame.nil?
      # create new frame if necessary
      process.new_frame
    end

    # switch page directory
    if process.kernel_process?
      Paging.current_pdpt = Pointer(Paging::Data::PDPTable)
        .new(process.phys_user_pg_struct)
      Paging.current_kernel_pdpt = Pointer(Paging::Data::PDPTable)
        .new(process.phys_pg_struct)
    else
      Paging.current_pdpt = Pointer(Paging::Data::PDPTable)
        .new(process.phys_pg_struct)
    end
    Paging.flush

    # restore fxsave
    unless process.fxsave_region.null?
      memcpy Multiprocessing.fxsave_region, process.fxsave_region, FXSAVE_SIZE
    end

    # lock kernel subsytems for driver threads
    if process.kernel_process?
      DriverThread.lock
    end
  end

  private def halt_processor
    rsp = Gdt.stack
    asm("mov $0, %rsp
          mov %rsp, %rbp
          sti" :: "r"(rsp) : "volatile", "{rsp}", "{rbp}")
    while true
      asm("hlt")
    end
  end

  # context switch
  private def switch_process_save_and_load(remove = false, &block)
    # Serial.print "---\n"
    # switching from idle process
    if @@current_process.nil?
      @@current_process = get_next_process
      if @@current_process.nil?
        halt_processor
      end
      next_process = @@current_process.not_nil!
      context_switch_to_process(next_process)
      return next_process
    end

    current_process = @@current_process.not_nil!

    # set process' state to idle
    if remove
      current_process.sched_data.status = ProcessData::Status::Removed
    elsif current_process.sched_data.status == ProcessData::Status::Running
      current_process.sched_data.status = ProcessData::Status::Normal
    end

    # get next process
    next_process = get_next_process
    @@current_process = next_process

    # remove or save current process state
    if remove
      current_process.remove
    else
      yield current_process
      unless current_process.fxsave_region.null?
        memcpy current_process.fxsave_region, Multiprocessing.fxsave_region, FXSAVE_SIZE
      end
    end

    if next_process.nil?
      if remove
        Paging.free_process_pdpt(current_process.phys_pg_struct)
      end
      halt_processor
    end

    next_process = next_process.not_nil!
    next_process.sched_data.time_slice = NORMAL_TIME_SLICE
    next_process.sched_data.status = ProcessData::Status::Running
    context_switch_to_process(next_process)

    if remove
      Paging.free_process_pdpt(current_process.phys_pg_struct)
    end

    # Serial.print "next: ", next_process.name, "\n"
    next_process
  end

  def switch_process(frame : Idt::Data::Registers*)
    current_process = switch_process_save_and_load do |process|
      process.frame.not_nil!.to_unsafe.value = frame.value
    end
    frame.value = current_process.frame.not_nil!.to_unsafe.value
  end

  def switch_process(frame : SyscallData::Registers*)
    Syscall.unlock
    current_process = switch_process_save_and_load do |process|
      process.new_frame_from_syscall frame
    end
    Kernel.ksyscall_switch(current_process.frame.not_nil!.to_unsafe)
  end

  def switch_process_and_terminate
    Syscall.unlock
    current_process = switch_process_save_and_load(true) { }
    Kernel.ksyscall_switch(current_process.frame.not_nil!.to_unsafe)
  end
end
