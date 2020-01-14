module Syscall::Handlers
  extend self

  def mmap_drv(args : Syscall::Arguments)
    virt_addr = args.frame.value.rbx
    page = Paging.alloc_page(
      virt_addr, args.frame.value.rdx != 0, args.frame.value.r8 != 0,
      args.frame.value.r9,
      execute: args.frame.value.r10 != 0
    )
    if virt_addr <= Paging::PDPT_SIZE && args.process.phys_user_pg_struct == 0u64
      args.process.phys_user_pg_struct = Paging.real_pdpt.address
    end
    page
  end

  def process_create_drv(args : Syscall::Arguments)
    result = Pointer(ElfReader::Result).new(args.frame.value.rbx).value
    udata = Pointer(Void).new(args.frame.value.rdx).as(Multiprocessing::Process::UserData)
    process = Multiprocessing::Process.spawn_user(udata, result)
    process.pid
  end

  def sleep_drv(args : Syscall::Arguments)
    args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
    Multiprocessing::Scheduler.switch_process(args.frame)
  end
end
