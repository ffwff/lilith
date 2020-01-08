module Syscall::Handlers
  extend self

  def time(args : Syscall::Arguments)
    if args.process.udata.is64
      Time.stamp
    else
      lo = Time.stamp & 0xFFFF_FFFF
      hi = Time.stamp >> 32
      args.frame.value.rbx = hi
      lo
    end
  end

  def sleep(args : Syscall::Arguments)
    hi = args[0].to_u32
    lo = args[1].to_u32
    timeout = hi.to_u64 << 32 | lo.to_u64
    if timeout == 0
      sysret(0)
    elsif timeout == (-1).to_u64
      process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
    else
      process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::Sleep
      pudata.wait_usecs timeout
    end
    Multiprocessing::Scheduler.switch_process(frame)
  end

end
