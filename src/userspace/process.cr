require "./file_descriptor.cr"
require "./mmap_list.cr"
require "./driver_thread.cr"

private lib Kernel
  fun ksyscall_switch(frame : IdtData::Registers*) : NoReturn
end

module Multiprocessing
  extend self

  # must be page aligned
  USER_STACK_TOP        = 0xFFFF_F000u64
  USER_STACK_SIZE       =   0x80_0000u64 # 8 mb
  USER_STACK_BOTTOM_MAX = USER_STACK_TOP - USER_STACK_SIZE
  USER_STACK_BOTTOM     = 0x8000_0000u64

  USER_STACK_INITIAL = 0xFFFF_FFFFu64
  USER_MMAP_INITIAL  = USER_STACK_BOTTOM_MAX

  KERNEL_STACK_INITIAL = Paging::KERNEL_PDPT_POINTER + 0x7F_FFFF_FFFFu64
  KERNEL_HEAP_INITIAL  = Paging::KERNEL_PDPT_POINTER + 0x0u64

  USER_CS_SEGMENT =  0x1b
  USER_SS_SEGMENT =  0x23
  USER_RFLAGS     = 0x212

  KERNEL_CS_SEGMENT =   0x29
  KERNEL_SS_SEGMENT =   0x31
  KERNEL_RFLAGS     = 0x1202 # IOPL=1

  FXSAVE_SIZE = 512u64

  @@current_process : Process? = nil

  def current_process
    @@current_process
  end

  def current_process=(@@current_process); end

  @@first_process : Process? = nil
  mod_property first_process
  @@last_process : Process? = nil
  mod_property last_process

  @@pids = 0
  mod_property pids
  @@n_process = 0
  mod_property n_process
  @@fxsave_region = Pointer(UInt8).null

  def fxsave_region
    @@fxsave_region
  end

  def fxsave_region=(@@fxsave_region); end

  @@procfs : ProcFS? = nil

  def procfs
    @@procfs
  end

  def procfs=(@@procfs); end

  class Process
    @pid = 0
    getter pid

    @prev_process : Process? = nil
    @next_process : Process? = nil
    getter prev_process, next_process

    protected def prev_process=(@prev_process); end

    protected def next_process=(@next_process); end

    @initial_ip = 0x8000_0000u64
    property initial_ip

    @initial_sp = 0u64
    property initial_sp

    # physical location of the process' page directory
    @phys_pg_struct : UInt64 = 0u64
    property phys_pg_struct
    
    @phys_user_pg_struct : UInt64 = 0u64
    property phys_user_pg_struct

    # interrupt frame for preemptive multitasking
    @frame : Box(IdtData::Registers)? = nil
    property frame

    # sse state
    # FIXME: fxsave_region is manually allocated to save memory
    @fxsave_region = Pointer(UInt8).null
    getter fxsave_region

    # status
    enum Status
      Removed
      Normal
      Running
      WaitIo
      WaitProcess
      WaitFd
      Sleep
    end

    @status = Status::Normal
    property status

    # user-mode process data
    class UserData
      # wait process / file
      # TODO: this should be a weak pointer once it's implemented
      @wait_object : (Process | FileDescriptor | GcArray(FileDescriptor))? = nil
      property wait_object

      # wait useconds
      @wait_usecs = 0u32
      property wait_usecs

      # group id
      @pgid = 0u64
      property pgid

      # files
      MAX_FD = 16
      property fds

      # mmap
      getter mmap_list

      @mmap_heap : MemMapNode? = nil
      property mmap_heap

      # working directory
      property cwd
      property cwd_node

      # argv
      property argv

      class EnvVar
        getter key
        property value

        def initialize(@key : GcString, @value : GcString)
        end
      end

      # environment variables
      getter environ

      def initialize(@argv : GcArray(GcString),
                     @cwd : GcString, @cwd_node : VFSNode,
                     @environ = GcArray(EnvVar).new(0))
        @fds = GcArray(FileDescriptor).new MAX_FD
        @mmap_list = MemMapList.new
      end

      # file descriptors
      def install_fd(node : VFSNode, attrs) : Int32
        i = 0
        while i < @fds.size
          if @fds[i].nil?
            @fds[i] = FileDescriptor.new(i, node, attrs)
            return i
          end
          i += 1
        end
        -1
      end

      def get_fd(i : Int32) : FileDescriptor?
        @fds[i]?
      end

      def close_fd(i : Int32) : Bool
        return false unless i >= 0 && i <= @fds.size
        return false if @fds[i].nil?
        @fds[i] = nil
        true
      end

      # environ
      def getenv(key)
        @environ.each do |env|
          return env.not_nil!.value if env.not_nil!.key == key
        end
      end

      def setenv(key, value, override = false)
        @environ.each do |env|
          if env.not_nil!.key == key
            return false unless override
            env.not_nil!.value = value
            return true
          end
        end
        @environ.push(EnvVar.new(key, value))
        true
      end
    end

    @udata : UserData? = nil

    def udata
      @udata.not_nil!
    end

    def kernel_process?
      @udata.nil?
    end

    getter name

    def initialize(@name : GcString?, @udata : UserData? = nil, &on_setup_paging : Process -> _)
      Multiprocessing.n_process += 1
      @pid = Multiprocessing.pids
      Multiprocessing.pids += 1

      if kernel_process?
        @initial_sp = KERNEL_STACK_INITIAL
      else
        @initial_sp = USER_STACK_INITIAL
      end

      Idt.disable

      if @pid != 0
        @fxsave_region = Pointer(UInt8).mmalloc(FXSAVE_SIZE)
        memset(@fxsave_region, 0x0, FXSAVE_SIZE)
      end

      # create vmm map and save old vmm map
      last_pg_struct = Pointer(PageStructs::PageDirectoryPointerTable).null
      if @pid != 0
        page_struct = Paging.alloc_process_pdpt
        if kernel_process?
          last_pg_struct = Paging.current_kernel_pdpt
          Paging.current_kernel_pdpt = Pointer(PageStructs::PageDirectoryPointerTable).new page_struct
        else
          last_pg_struct = Paging.current_pdpt
          Paging.current_pdpt = Pointer(PageStructs::PageDirectoryPointerTable).new page_struct
        end
        Paging.flush
        @phys_pg_struct = page_struct
      else
        @phys_pg_struct = 0u64
      end

      # setup process
      unless yield self
        # unable to setup, bailing
        if kernel_process?
          panic "unable to set up kernel process"
        end
        unless last_pg_struct.null?
          Paging.current_pdpt = last_pg_struct
          Paging.flush
        end
        Idt.enable
        Multiprocessing.n_process -= 1
        Multiprocessing.pids -= 1
        return
      end

      # append to linked list
      if Multiprocessing.first_process.nil?
        Multiprocessing.first_process = self
        Multiprocessing.last_process = self
      else
        Multiprocessing.last_process.not_nil!.next_process = self
        @prev_process = Multiprocessing.last_process
        Multiprocessing.last_process = self
      end

      # restore vmm map
      unless last_pg_struct.null?
        if kernel_process?
          Paging.current_kernel_pdpt = last_pg_struct
        else
          Paging.current_pdpt = last_pg_struct
        end
        Paging.flush
      end

      # append to procfs
      if Multiprocessing.procfs
        Multiprocessing.procfs.not_nil!.root.not_nil!.create_for_process(self)
      end

      Idt.enable
    end

    def initial_switch
      Multiprocessing.current_process = self
      panic "page dir is nil" if @phys_pg_struct == 0
      if kernel_process?
        DriverThread.lock
        Paging.current_kernel_pdpt = Pointer(PageStructs::PageDirectoryPointerTable).new(@phys_pg_struct)
        Paging.flush
      else
        Paging.current_pdpt = Pointer(PageStructs::PageDirectoryPointerTable).new(@phys_pg_struct)
        Paging.flush
      end
      Kernel.ksyscall_switch(@frame.not_nil!.to_unsafe)
    end

    # new register frame for multitasking
    def new_frame
      frame = IdtData::Registers.new
      frame.userrsp = @initial_sp
      frame.rip = @initial_ip
      if kernel_process?
        frame.rflags = KERNEL_RFLAGS
        frame.cs = KERNEL_CS_SEGMENT
        frame.ss = KERNEL_SS_SEGMENT
        frame.ds = KERNEL_SS_SEGMENT
      else
        frame.rflags = USER_RFLAGS
        frame.cs = USER_CS_SEGMENT
        frame.ds = USER_SS_SEGMENT
        frame.ss = USER_SS_SEGMENT
      end

      if @frame.nil?
        @frame = Box.new(frame)
      else
        @frame.not_nil!.to_unsafe.value = frame
      end
    end

    def new_frame_from_syscall(syscall_frame : SyscallData::Registers*)
      frame = IdtData::Registers.new

      {% for id in [
                     "rbp", "rdi", "rsi",
                     "r15", "r14", "r13", "r12", "r11", "r10", "r9", "r8",
                     "rdx", "rcx", "rbx", "rax",
                   ] %}
      frame.{{ id.id }} = syscall_frame.value.{{ id.id }}
      {% end %}

      # setup frame for waking up
      if kernel_process?
        frame.rip = syscall_frame.value.rcx
        frame.userrsp = syscall_frame.value.rsp

        frame.rflags = frame.r11
        frame.cs = KERNEL_CS_SEGMENT
        frame.ss = KERNEL_SS_SEGMENT
        frame.ds = KERNEL_SS_SEGMENT
      else
        frame.rip = Pointer(UInt32).new(syscall_frame.value.rcx).value
        frame.userrsp = syscall_frame.value.rcx & 0xFFFF_FFFFu64

        frame.rflags = USER_RFLAGS
        frame.cs = USER_CS_SEGMENT
        frame.ss = USER_SS_SEGMENT
        frame.ds = USER_SS_SEGMENT
      end

      if @frame.nil?
        @frame = Box.new(frame)
      else
        @frame.not_nil!.to_unsafe.value = frame
      end
    end

    # spawn user process and move the lower-half of the current the address space
    # to the newly-spawned user process
    @[NoInline]
    def self.spawn_user(initial_ip : UInt64, heap_start : UInt64,
          udata : UserData, mmap_list : Slice(ElfReader::InlineMemMapNode))
      old_pdpt = Pointer(PageStructs::PageDirectoryPointerTable)
        .new(Paging.mt_addr(Paging.current_pdpt.address))
      Multiprocessing::Process.new(udata.argv[0].not_nil!, udata) do |process|
        process.initial_ip = initial_ip

        # TODO: move this
        new_pdpt = Pointer(PageStructs::PageDirectoryPointerTable)
          .new(Paging.mt_addr(process.phys_pg_struct))

        512.times do |dir_idx|
          # move the pdpt over and zero out the source
          new_pdpt.value.dirs[dir_idx] = old_pdpt.value.dirs[dir_idx]
          old_pdpt.value.dirs[dir_idx] = 0u64
        end
        Paging.current_pdpt = Pointer(Void).new(process.phys_pg_struct)
        Paging.flush

        # memory map
        mmap_list.each do |mmap_node|
          next if mmap_node.memsz == 0u64
          region_start = Paging.t_addr(mmap_node.vaddr)
          region_end = Paging.aligned(mmap_node.vaddr + mmap_node.memsz)
          region_size = region_end - region_start
          udata.mmap_list.add(region_start, region_size, mmap_node.attrs)
        end
        
        udata.mmap_heap = udata.mmap_list.add(heap_start, 0,
          MemMapNode::Attributes::Read | MemMapNode::Attributes::Write).not_nil!

        # argv
        argv_builder = ArgvBuilder.new process
        udata.argv.each do |arg|
          argv_builder.from_string arg.not_nil!
        end
        argv_builder.build
        true
      end
    end

    @[NoInline]
    def self.spawn_user_drv(initial_ip : UInt64, heap_start : UInt64,
          udata : UserData, mmap_list : Slice(ElfReader::InlineMemMapNode))
      retval = 0u64
      mmap_list_addr = mmap_list.to_unsafe.address
      mmap_list_size = mmap_list.size
      asm("syscall"
              : "={rax}"(retval)
              : "{rax}"(SC_PROCESS_CREATE_DRV),
                "{rbx}"(initial_ip),
                "{rdx}"(heap_start),
                "{r8}"(udata),
                "{r9}"(mmap_list_addr),
                "{r10}"(mmap_list_size)
              : "cc", "memory", "{rcx}", "{r11}", "{rdi}", "{rsi}")
      retval
    end

    # spawn kernel process with optional argument
    def self.spawn_kernel(name : GcString, function, arg : Void*? = nil, stack_pages = 1, &block)
      Multiprocessing::Process.new(name) do |process|
        stack_start = Paging.t_addr(process.initial_sp) - (stack_pages - 1) * 0x1000
        stack = Paging.alloc_page_pg(stack_start, true, false, npages: stack_pages.to_u64)
        process.initial_ip = function.pointer.address

        yield process

        unless arg.nil?
          process.new_frame
          process.frame.not_nil!.to_unsafe.value.rdi = arg.not_nil!.address
        end
        true
      end
    end

    # deinitialize
    def remove
      Multiprocessing.n_process -= 1
      @prev_process.not_nil!.next_process = @next_process
      if @next_process.nil?
        Multiprocessing.last_process = @prev_process
      else
        @next_process.not_nil!.prev_process = @prev_process
      end
      # cleanup manually allocated fxsave region
      @fxsave_region.mfree
      @fxsave_region = Pointer(UInt8).null
      # cleanup gc data so as to minimize leaks
      @udata = nil
      @frame = nil
      @prev_process = nil
      @next_process = nil
      @status = Status::Removed
      # remove from procfs
      if Multiprocessing.procfs
        Multiprocessing.procfs.not_nil!.root.not_nil!.remove_for_process(self)
      end
    end

    # write address to page without switching tlb to the process' pdpt
    def write_to_virtual(virt_ptr : UInt8*, byte : UInt8)
      return false if @phys_pg_struct == 0

      virt_addr = virt_ptr.address
      return false if virt_addr > PDPT_SIZE

      offset = virt_addr & 0xFFF
      _, dir_idx, table_idx, page_idx = Paging.page_layer_indexes(virt_addr)

      pdpt = Pointer(PageStructs::PageDirectoryPointerTable)
        .new(Paging.mt_addr @phys_pg_struct)

      pd = Pointer(PageStructs::PageDirectory).new(Paging.mt_addr pdpt.value.dirs[dir_idx])
      return false if pd.null?

      pt = Pointer(PageStructs::PageTable).new(Paging.mt_addr pd.value.tables[table_idx])
      return false if pt.null?

      bytes = Pointer(UInt8).new(Paging.mt_addr(pt.value.pages[page_idx]))
      bytes[offset] = byte

      true
    end

    # get physical page where the address belongs to
    def physical_page_for_address(virt_addr : UInt64)
      return if @phys_pg_struct == 0
      return if virt_addr > PDPT_SIZE

      _, dir_idx, table_idx, page_idx = Paging.page_layer_indexes(virt_addr)

      pdpt = Pointer(PageStructs::PageDirectoryPointerTable)
        .new(Paging.mt_addr @phys_pg_struct)

      pd = Pointer(PageStructs::PageDirectory).new(Paging.mt_addr pdpt.value.dirs[dir_idx])
      return if pd.null?

      pt = Pointer(PageStructs::PageTable).new(Paging.mt_addr pd.value.tables[table_idx])
      return if pt.null?

      Pointer(UInt8).new(Paging.mt_addr(pt.value.pages[page_idx]))
    end

    # debugging
    def to_s(io)
      io.puts "Process {\n"
      io.puts " pid: ", @pid, ", \n"
      io.puts " status: ", @status, ", \n"
      io.puts " initial_sp: ", Pointer(Void).new(@initial_sp), ", \n"
      io.puts " initial_ip: ", Pointer(Void).new(@initial_ip), ", \n"
      io.puts "}"
    end

    protected def unawait
      @status = Multiprocessing::Process::Status::Normal
      @udata.not_nil!.wait_object = nil
      @udata.not_nil!.wait_usecs = 0u32
    end
  end

  private def can_switch(process)
    case process.status
    when Multiprocessing::Process::Status::Normal
      true
    when Multiprocessing::Process::Status::Removed
      false
    when Multiprocessing::Process::Status::WaitIo
      false
    when Multiprocessing::Process::Status::WaitProcess
      wait_object = process.udata.wait_object
      case wait_object
      when Process
        if wait_object.as(Process).status == Multiprocessing::Process::Status::Removed
          process.unawait
          true
        end
        false
      when Nil
        process.unawait
        true
      end
    when Multiprocessing::Process::Status::WaitFd
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
    when Multiprocessing::Process::Status::Sleep
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
  def next_process : Process?
    if @@current_process.nil?
      return @@current_process = @@first_process
    end
    process = @@current_process.not_nil!
    # look from middle to end
    cur = process.next_process
    while !cur.nil? && !can_switch(cur.not_nil!)
      cur = cur.next_process
    end
    @@current_process = cur
    # look from start to middle
    if @@current_process.nil?
      cur = @@first_process.not_nil!.next_process
      while !cur.nil? && !can_switch(cur.not_nil!)
        cur = cur.not_nil!.next_process
        break if cur == process.prev_process
      end
      @@current_process = cur
    end
    if @@current_process.nil? || !can_switch(@@current_process.not_nil!)
      # no tasks left, use idle
      @@current_process = @@first_process
    else
      @@current_process
    end
  end

  # sleep from kernel thread
  def sleep_drv
    retval = 0u64
    asm("syscall"
            : "={rax}"(retval)
            : "{rax}"(SC_SLEEP)
            : "cc", "memory", "{rcx}", "{r11}", "{rdi}", "{rsi}")
    retval
  end

  # context switch
  private def switch_process_save_and_load(remove = false, &block)
    # get next process
    current_process = Multiprocessing.current_process.not_nil!
    if remove
      current_process.status = Process::Status::Removed
    elsif current_process.status == Process::Status::Running
      current_process.status = Process::Status::Normal
    end
    next_process = Multiprocessing.next_process.not_nil!
    next_process.status = Process::Status::Running
    Multiprocessing.current_process = next_process
    current_process.remove if remove

    # save current process' state
    if current_process.pid != 0 && !remove
      yield current_process
      unless current_process.fxsave_region.null?
        memcpy current_process.fxsave_region, Multiprocessing.fxsave_region, FXSAVE_SIZE
      end
    end

    if next_process.pid == 0
      # halt the processor in pid 0
      rsp = Gdt.stack
      asm("mov $0, %rsp
           mov %rsp, %rbp
           sti" :: "r"(rsp) : "volatile", "{rsp}", "{rbp}")
      while true
        asm("hlt")
      end
    elsif next_process.frame.nil?
      # create new frame if necessary
      next_process.new_frame
    end

    # switch page directory
    if next_process.kernel_process?
      breakpoint
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

  # iteration
  def each
    process = @@first_process
    while !process.nil?
      process = process.not_nil!
      yield process
      process = process.next_process
    end
  end
end
