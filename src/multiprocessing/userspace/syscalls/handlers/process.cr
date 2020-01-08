module Syscall::Handlers
  extend self

  def spawn(args : Syscall::Arguments)
    path = checked_slice(args[0], args[1]) || return EFAULT
    startup_info = checked_pointer(Syscall::Data::SpawnStartupInfo32, arg(2))
    if pudata.is64
      argv = checked_pointer(UInt64, args[3]) || return EFAULT
    else
      argv = checked_pointer(UInt32, args[3]) || return EFAULT
    end

    # search in path env
    vfs_node = unless (path_env = pudata.getenv("PATH")).nil?
      # TODO: parse multiple paths
      unless (dir = parse_path_into_vfs(path_env.byte_slice, process, frame)).nil?
        parse_path_into_vfs path, process, frame, dir
      end
    end
    # search binary in cwd
    if vfs_node.nil?
      vfs_node = parse_path_into_vfs path, process, frame, pudata.cwd_node
    end

    if vfs_node.nil?
      return ENOENT
    else
      # argv
      pargv = Array(String).new 0
      i = 0
      while i < SC_SPAWN_MAX_ARGS
        if argv[i] == 0
          break
        end
        # FIXME: check for size of NullTerminatedSlice
        arg = NullTerminatedSlice.new(try(checked_pointer(UInt8, argv[i].to_u64), EFAULT))
        pargv.push String.new(arg)
        i += 1
      end

      udata = Multiprocessing::Process::UserData
        .new(pargv,
          pudata.cwd.clone,
          pudata.cwd_node,
          pudata.environ.clone)
      udata.pgid = args.process.udata.pgid

      # copy file descriptors 0, 1, 2
      if !startup_info.nil?
        startup_info = startup_info.not_nil!
        if (fd = args.process.udata.fds[startup_info.value.stdin]?)
          args.udata.fds.push fd.clone(0)
        else
          args.udata.fds.push nil
        end
        if (fd = args.process.udata.fds[startup_info.value.stdout]?)
          args.udata.fds.push fd.clone(1)
        else
          args.udata.fds.push nil
        end
        if (fd = args.process.udata.fds[startup_info.value.stderr]?)
          args.udata.fds.push fd.clone(2)
        else
          args.udata.fds.push nil
        end
      else
        3.times do |i|
          if (fd = args.process.udata.fds[i])
            args.udata.fds.push fd.clone(i)
          end
          i += 1
        end
      end

      # create the process
      retval = vfs_node.not_nil!.spawn(udata)
      case retval
      when VFS_WAIT
        vfs_node.fs.queue.not_nil!
          .enqueue(VFS::Message.new(udata, vfs_node, process))
        args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
        Multiprocessing::Scheduler.switch_process(frame)
      else
        return retval
      end
    end
  end

  def waitpid(args : Syscall::Arguments)
    pid = args[0].to_i32
    if pid <= 0
      # wait for any child process
      Serial.print "waitpid: pid <= 0 unimplemented"
      return EINVAL
    else # pid > 0
      cprocess = nil
      Multiprocessing.each do |proc|
        if proc.pid == pid
          cprocess = proc
          break
        end
      end
      if cprocess.nil?
        return EINVAL
      else
        args.frame.value.rax = pid
        args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitProcess
        pudata.wait_object = cprocess
        Multiprocessing::Scheduler.switch_process(frame)
      end
    end
  end

  def exit(args : Syscall::Arguments)
    Multiprocessing::Scheduler.switch_process_and_terminate
  end

end
