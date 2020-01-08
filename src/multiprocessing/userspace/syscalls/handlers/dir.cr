module Syscall::Handlers
  extend self

  def readdir(args : Syscall::Arguments)
    fd = args.process.udata.get_fd(args[0].to_i32) || return EBADFD
    retval = checked_pointer(Syscall::Data::DirentArgument32, args[1]) || return EFAULT
    if fd.cur_child_end
      return 0
    elsif fd.cur_child.nil?
      if !fd.node.not_nil!.dir_populated
        vfs_node = fd.node.not_nil!
        case vfs_node.populate_directory
        when VFS_OK
          # ignored
        when VFS_WAIT
          vfs_node.fs.queue.not_nil!
            .enqueue(VFS::Message.new(vfs_node, args.process))
          args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
          Multiprocessing::Scheduler.switch_process(args.frame)
        end
      end
      if (child = fd.node.not_nil!.first_child).nil?
        return ENOENT
      end
      fd.cur_child = child
    end

    child = fd.cur_child.not_nil!

    dirent = Syscall::Data::DirentArgument32.new
    dirent.d_ino = 0
    dirent.d_reclen = sizeof(Syscall::Data::DirentArgument32)
    dirent.d_type = 0
    if (name = child.name).nil?
      dirent.d_name[0] = '/'.ord.to_u8
      dirent.d_name[1] = 0
    else
      name = name.not_nil!
      i = 0
      while i < Math.min(name.bytesize, dirent.d_name.size - 1)
        dirent.d_name[i] = name.to_unsafe[i]
        i += 1
      end
      dirent.d_name[i] = 0
    end
    retval.value = dirent

    fd.cur_child = child.next_node
    if fd.cur_child.nil?
      fd.cur_child_end = true
    end
    1
  end

  def getcwd(args : Syscall::Arguments)
    if args[0] == 0
      return args.process.udata.cwd.size
    end
    str = checked_slice(args[0], args[1]) || return EFAULT
    if str.size > SC_PATH_MAX
      return EINVAL
    end
    idx = 0
    args.process.udata.cwd.each_byte do |ch|
      break if idx == str.size - 1
      str[idx] = ch
      idx += 1
    end
    str[idx] = 0
    idx
  end

  def chdir(args : Syscall::Arguments)
    path = checked_slice(args[0], args[1]) || return EFAULT
    if tuple = Syscall::Path.append_paths path,
                            args.process.udata.cwd,
                            args.process.udata.cwd_node
      cwd, vfs_node = tuple
      if !vfs_node.nil?
        args.process.udata.cwd = cwd
        args.process.udata.cwd_node = vfs_node.not_nil!
        0
      else
        EINVAL
      end
    else
      ENOENT
    end
  end

end
