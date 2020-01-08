module Syscall::Handlers
  extend self

  def spawn(args : Syscall::Arguments)
    path = checked_slice(args[0], args[1]) || return EFAULT
    startup_info = checked_pointer(Syscall::Data::SpawnStartupInfo32, args[2])
    if args.process.udata.is64
      argv = checked_pointer(UInt64, args[3]) || return EFAULT
    else
      argv = checked_pointer(UInt32, args[3]) || return EFAULT
    end

    # search in path env
    vfs_node = if path_env = args.process.udata.getenv("PATH")
                 # TODO: parse multiple paths
                 if dir = Syscall::Path.parse_path_into_vfs(path_env.byte_slice, args)
                   Syscall::Path.parse_path_into_vfs path, args, cw_node: dir
                 end
               end

    # search binary in cwd
    if vfs_node.nil?
      vfs_node = Syscall::Path.parse_path_into_vfs path, args,
                          cw_node: args.process.udata.cwd_node
    end

    if vfs_node.nil?
      return ENOENT
    else
      # argv
      pargv = Array(String).new
      i = 0
      while i < SC_SPAWN_MAX_ARGS
        if argv[i] == 0
          break
        end
        argp = checked_pointer(UInt8, argv[i].to_u64) || return EFAULT
        pargv.push String.new(NullTerminatedSlice.new(argp, SC_SPAWN_MAX_ARGLEN))
        i += 1
      end

      udata = Multiprocessing::Process::UserData
        .new(pargv,
          args.process.udata.cwd,
          args.process.udata.cwd_node,
          args.process.udata.environ.clone)
      udata.pgid = args.process.udata.pgid

      # copy file descriptors 0, 1, 2
      if !startup_info.nil?
        startup_info = startup_info.not_nil!
        {% for idx, fd in {0 => "stdin", 1 => "stdout", 2 => "stderr"} %}
          if fd = args.process.udata.fds[startup_info.value.{{ fd.id }}]?
            udata.fds.push fd.clone({{ idx }})
          else
            udata.fds.push nil
          end
        {% end %}
      else
        3.times do |i|
          if fd = args.process.udata.fds[i]?
            udata.fds.push fd.clone(i)
          end
          i += 1
        end
      end

      # create the process
      retval = vfs_node.not_nil!.spawn(udata)
      case retval
      when VFS_WAIT
        vfs_node.fs.queue.not_nil!
          .enqueue(VFS::Message.new(udata, vfs_node, args.process))
        args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
        Multiprocessing::Scheduler.switch_process(args.frame)
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
        args.primary_arg = pid
        args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitProcess
        args.process.udata.wait_object = cprocess
        Multiprocessing::Scheduler.switch_process(args.frame)
      end
    end
  end

  def exit(args : Syscall::Arguments)
    Multiprocessing::Scheduler.switch_process_and_terminate
  end

  def getenv(args : Syscall::Arguments)
    EINVAL
  end

  def setenv(args : Syscall::Arguments)
    EINVAL
  end

end
