module Syscall::Handlers
  extend self

  def readdir(args : Syscall::Arguments)
    fd = pudata.get_fd(arg[0].to_i32) || return EBADFD
    retval = checked_pointer(Syscall::Data::DirentArgument32, arg[1]) || return EFAULT
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
            .enqueue(VFS::Message.new(vfs_node, process))
          process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
          Multiprocessing::Scheduler.switch_process(frame)
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
    0
  end

  def getcwd(args : Syscall::Arguments)
    if arg[0] == 0
      return pudata.cwd.size
    end
    str = checked_slice(arg(0), arg(1)) || return EFAULT
    if str.size > SC_PATH_MAX
      return EINVAL
    end
    idx = 0
    pudata.cwd.each_byte do |ch|
      break if idx == str.size - 1
      str[idx] = ch
      idx += 1
    end
    str[idx] = 0
    idx
  end

  def chdir(args : Syscall::Arguments)
    path = checked_slice(arg(0), arg(1)) || return EFAULT
    if (t = append_paths path, pudata.cwd, pudata.cwd_node).nil?
      ENOENT
    else
      cwd, vfs_node = t.not_nil!
      if !vfs_node.nil?
        pudata.cwd = cwd
        pudata.cwd_node = vfs_node.not_nil!
        0
      else
        EINVAL
      end
    end
  end

end
