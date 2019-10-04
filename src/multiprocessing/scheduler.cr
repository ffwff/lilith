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
      
      @queue_id = -1
      property queue_id

      def initialize(@queue_id, @process : Multiprocessing::Process)
      end

      def can_switch? : Bool
        process = self.process
        # Serial.puts "next_process: ", process, '\n'
        case @status
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
          else
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
        if current_process.nil?
          sched_data = @first_data.not_nil!
          cur = sched_data
        else
          sched_data = current_process.not_nil!.sched_data
          return nil if sched_data.queue_id != @queue_id
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
    end
    
    @@queue = Queue.new 0

    def append_process(process : Process)
      sched_data = ProcessData.new(@@queue.queue_id, process)
      @@queue.append_process_data sched_data
      sched_data
    end

    def remove_process(process : Process)
      sched_data = process.sched_data
      case sched_data.queue_id
      when 0
        @@queue.remove_process_data sched_data
      else
        panic "unknown queue_id: ", sched_data.queue_id
      end
    end

    @@current_process : Multiprocessing::Process? = nil
    
    def current_process
      @@current_process
    end

    private def context_switch_to_process(process : Multiprocessing::Process)
      if process.frame.nil?
        # create new frame if necessary
        process.new_frame
      end

      # switch page directory
      if process.kernel_process?
        Paging.current_pdpt = Pointer(PageStructs::PageDirectoryPointerTable)
          .new(process.phys_user_pg_struct)
        Paging.current_kernel_pdpt = Pointer(PageStructs::PageDirectoryPointerTable)
          .new(process.phys_pg_struct)
      else
        Paging.current_pdpt = Pointer(PageStructs::PageDirectoryPointerTable)
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
      # switching from idle process
      if @@current_process.nil?
        @@current_process = @@queue.next_process
        if @@current_process.nil?
          halt_processor
        end
        next_process = @@current_process.not_nil!
        context_switch_to_process(next_process)
        return next_process
      end
    
      # get next process and save current process
      current_process = @@current_process.not_nil!
      if current_process.sched_data.status == ProcessData::Status::Running
        current_process.sched_data.status = ProcessData::Status::Normal
      end
      next_process = @@queue.next_process @@current_process
      @@current_process = next_process
      
      # remove or save current process state
      if remove
        panic "current_process == next_process" if current_process == next_process
        current_process.remove
      else
        yield current_process
        unless current_process.fxsave_region.null?
          memcpy current_process.fxsave_region, Multiprocessing.fxsave_region, FXSAVE_SIZE
        end
      end

      if next_process.nil?
        halt_processor
      end

      next_process = next_process.not_nil!
      next_process.sched_data.status = ProcessData::Status::Running
      context_switch_to_process(next_process)

      if remove
        Paging.free_process_pdpt(current_process.phys_pg_struct)
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
