private lib Kernel
  fun ksyscall_switch(frame : IdtData::Registers*) : NoReturn
end

module Multiprocessing

  module Scheduler
    extend self

    def current_process=(@@current_process); end
    
    class ProcessData
      @next_data : ProcessData? = nil
      @prev_data : ProcessData? = nil
      property next_data, prev_data
      
      @status = Status::Normal
      
      getter process

      # status
      enum Status
        Normal
        Running
        WaitIo
        WaitProcess
        WaitFd
        Sleep
      end
      @status = Status::Normal
      property status
    
      def initialize(@process : Multiprocessing::Process)
      end
    end
    
    @@first_data : ProcessData? = nil
    @@last_data : ProcessData? = nil
    @@current_process : Multiprocessing::Process? = nil
    
    def current_process
      @@current_process
    end

    protected def append_process(process : Process)
      sched_data = ProcessData.new(process)
      if @@first_data.nil?
        @@first_data = @@last_data = sched_data
      else
        @@last_data.not_nil!.next_data = sched_data
        sched_data.prev_data = @@last_data
        @@last_data = sched_data
      end
      sched_data
    end
    
    protected def remove_process(data : ProcessData)
      if @@first_data == data
        @@first_data = data.next_data
      end
      if @@last_data == data
        @@last_data = data.prev_data
      end
      if data.next_data
        data.next_data.not_nil!.prev_data = data.prev_data
      end
      if data.prev_data
        data.prev_data.not_nil!.next_data = data.next_data
      end
    end

    private def can_switch(data)
      process = data.process
      case data.status
      when ProcessData::Status::Normal
        true
      when ProcessData::Status::WaitIo
        false
      when ProcessData::Status::WaitProcess
        wait_object = process.udata.wait_object
        case wait_object
        when Process
          if wait_object.as(Process).removed?
            process.unawait
            true
          end
          false
        when Nil
          process.unawait
          true
        end
      when ProcessData::Status::WaitFd
        wait_object = process.udata.wait_object
        case wait_object
        when GcArray(FileDescriptor)
          if process.udata.wait_usecs != 0xFFFF_FFFFu32
            if process.udata.wait_usecs <= Pit::USECS_PER_TICK
              process.frame.not_nil!.to_unsafe.value.rax = 0
              process.unawait
              return true
            else
              process.udata.wait_usecs -= Pit::USECS_PER_TICK
            end
          end
          fds = wait_object.as(GcArray(FileDescriptor))
          fds.each do |fd|
            fd = fd.not_nil!
            if fd.node.not_nil!.available?
              process.frame.not_nil!.to_unsafe.value.rax = fd.idx
              process.unawait
              return true
            end
          end
          false
        when FileDescriptor
          if process.udata.wait_usecs != 0xFFFF_FFFFu32
            if process.udata.wait_usecs <= Pit::USECS_PER_TICK
              process.frame.not_nil!.to_unsafe.value.rax = 0
              process.unawait
              return true
            else
              process.udata.wait_usecs -= Pit::USECS_PER_TICK
            end
          end
          fd = wait_object.as(FileDescriptor)
          if fd.node.not_nil!.available?
            process.frame.not_nil!.to_unsafe.value.rax = fd.idx
            process.unawait
            true
          else
            false
          end
        when Nil
          process.unawait
          true
        end
      when ProcessData::Status::Sleep
        if process.udata.wait_usecs <= Pit::USECS_PER_TICK
          process.unawait
          true
        else
          process.udata.wait_usecs -= Pit::USECS_PER_TICK
          false
        end
      end
    end

    # round robin scheduling algorithm
    def get_next_process : Process?
      sched_data = @@current_process.not_nil!.sched_data
      # look from middle to end
      cur = sched_data.next_data
      while !cur.nil? && !can_switch(cur.not_nil!)
        cur = cur.next_data
      end
      # look from start to middle
      if cur.nil?
        cur = @@first_data
        while !cur.nil? && !can_switch(cur.not_nil!)
          cur = cur.not_nil!.next_data
          break if cur == sched_data.prev_data
        end
      end
      if cur
        @@current_process = cur.not_nil!.process
      end
    end

    # context switch
    private def switch_process_save_and_load(remove = false, &block)
      # get next process
      current_process = @@current_process.not_nil!
      if current_process.sched_data.status == ProcessData::Status::Running
        current_process.sched_data.status = ProcessData::Status::Normal
      end

      next_process = get_next_process
      
      if next_process.nil?
        # halt the processor in pid 0
        rsp = Gdt.stack
        asm("mov $0, %rsp
             mov %rsp, %rbp
             sti" :: "r"(rsp) : "volatile", "{rsp}", "{rbp}")
        while true
          asm("hlt")
        end
      end

      next_process = next_process.not_nil!
      next_process.sched_data.status = ProcessData::Status::Running
      current_process.remove if remove

      # save current process' state
      if !remove
        yield current_process
        unless current_process.fxsave_region.null?
          memcpy current_process.fxsave_region, Multiprocessing.fxsave_region, FXSAVE_SIZE
        end
      end

      if next_process.frame.nil?
        # create new frame if necessary
        next_process.new_frame
      end

      # switch page directory
      if next_process.kernel_process?
        Paging.current_pdpt = Pointer(PageStructs::PageDirectoryPointerTable)
          .new(next_process.phys_user_pg_struct)
        Paging.current_kernel_pdpt = Pointer(PageStructs::PageDirectoryPointerTable)
          .new(next_process.phys_pg_struct)
      else
        Paging.current_pdpt = Pointer(PageStructs::PageDirectoryPointerTable)
          .new(next_process.phys_pg_struct)
      end
      Paging.flush
      if remove
        Paging.free_process_pdpt(current_process.phys_pg_struct)
      end

      # restore fxsave
      unless next_process.fxsave_region.null?
        memcpy Multiprocessing.fxsave_region, next_process.fxsave_region, FXSAVE_SIZE
      end

      # lock kernel subsytems for driver threads
      if next_process.kernel_process?
        DriverThread.lock
      end

      next_process
    end

    def switch_process(frame : IdtData::Registers*)
      current_process = switch_process_save_and_load do |process|
        process.frame.not_nil!.to_unsafe.value = frame.value
      end
      frame.value = current_process.frame.not_nil!.to_unsafe.value
    end

    def switch_process(frame : SyscallData::Registers*)
      current_process = switch_process_save_and_load do |process|
        process.new_frame_from_syscall frame
      end
      Syscall.unlock
      Kernel.ksyscall_switch(current_process.frame.not_nil!.to_unsafe)
    end

    def switch_process_and_terminate
      current_process = switch_process_save_and_load(true) { }
      Syscall.unlock
      Kernel.ksyscall_switch(current_process.frame.not_nil!.to_unsafe)
    end
  end

end
