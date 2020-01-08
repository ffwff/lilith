module Syscall::Handlers
  extend self

  def open(args : Syscall::Arguments)
    path = checked_slice(args[0], args[1]) || return EFAULT
    vfs_node = Syscall::Path.parse_path_into_vfs(path, args,
          cw_node: args.process.udata.cwd_node) || return ENOENT
    args.process.udata.install_fd(vfs_node.not_nil!,
      FileDescriptor::Attributes.new(args[2].to_i32))
  end

  def create(args : Syscall::Arguments)
    path = checked_slice(args[0], args[1]) || return EFAULT
    options = args[2].to_i32
    vfs_node = Syscall::Path.parse_path_into_vfs(path, args,
          cw_node: args.process.udata.cwd_node,
          create: true, create_options: options) || return ENOENT
    args.process.udata.install_fd(vfs_node.not_nil!,
      FileDescriptor::Attributes.new(options))
  end

  def close(args : Syscall::Arguments)
    args.process.udata.close_fd(args[0].to_i32) ? 1 : -1
  end

  def remove(args : Syscall::Arguments)
    path = checked_slice(args[0], args[1]) || return EFAULT
    vfs_node = Syscall::Path.parse_path_into_vfs(path, args,
          cw_node: args.process.udata.cwd_node) || return ENOENT
    vfs_node.remove
  end

  def fattr(args : Syscall::Arguments)
    fd = args.process.udata.get_fd(args[0].to_i32) || return EBADFD
    fd.node.not_nil!.attributes.value
  end

  def read(args : Syscall::Arguments)
    fd = args.process.udata.get_fd(args[0].to_i32) || return EBADFD
    if !fd.attrs.includes?(FileDescriptor::Attributes::Read)
      return EBADFD
    elsif args[2] == 0u64
      return 0
    end
    str = checked_slice(args[1], args[2]) || return EFAULT
    result = fd.not_nil!.node.not_nil!.read(str, fd.offset, args.process)
    case result
    when VFS_WAIT_QUEUE
      vfs_node = fd.node.not_nil!
      vfs_node.queue.not_nil!
        .enqueue(VFS::Message.new(VFS::Message::Type::Read,
        str, args.process, fd, vfs_node))
      args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
      Multiprocessing::Scheduler.switch_process(args.frame)
    when VFS_WAIT
      vfs_node = fd.node.not_nil!
      vfs_node.fs.queue.not_nil!
        .enqueue(VFS::Message.new(VFS::Message::Type::Read,
        str, args.process, fd, vfs_node))
      args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
      Multiprocessing::Scheduler.switch_process(args.frame)
    else
      if result > 0
        fd.offset += result
      end
      result
    end
  end

  def write(args : Syscall::Arguments)
    fd = args.process.udata.get_fd(args[0].to_i32) || return EBADFD
    if !fd.attrs.includes?(FileDescriptor::Attributes::Write)
      return EBADFD
    elsif args[2] == 0u64
      return 0
    end
    str = checked_slice(args[1], args[2]) || return EINVAL
    result = fd.not_nil!.node.not_nil!.write(str, fd.offset, args.process)
    case result
    when VFS_WAIT_QUEUE
      vfs_node = fd.not_nil!.node.not_nil!
      vfs_node.queue.not_nil!
        .enqueue(VFS::Message.new(VFS::Message::Type::Write,
        str, args.process, fd, vfs_node))
      args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
      Multiprocessing::Scheduler.switch_process(args.frame)
    when VFS_WAIT
      vfs_node = fd.not_nil!.node.not_nil!
      vfs_node.fs.queue.not_nil!
        .enqueue(VFS::Message.new(VFS::Message::Type::Write,
        str, args.process, fd, vfs_node))
      args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
      Multiprocessing::Scheduler.switch_process(args.frame)
    else
      if result > 0
        fd.offset += result
      end
      result
    end
  end

  def truncate(args : Syscall::Arguments)
    fd = args.process.udata.get_fd(args[0].to_i32) || return EBADFD
    fd.node.not_nil!.truncate(args[1].to_i32)
  end

  def seek(args : Syscall::Arguments)
    fd = args.process.udata.get_fd(args[0].to_i32) || return EBADFD
    offset = args[1].to_i32
    whence = args[2].to_i32

    case whence
    when SC_SEEK_SET
      fd.offset = offset.to_u32
      fd.offset
    when SC_SEEK_CUR
      fd.offset += offset
      fd.offset
    when SC_SEEK_END
      fd.offset = (fd.node.not_nil!.size.to_i32 + offset).to_u32
      fd.offset
    else
      EINVAL
    end
  end

  def ioctl(args : Syscall::Arguments)
    fd = args.process.udata.get_fd(args[0].to_i32) || return EBADFD
    fd.node.not_nil!.ioctl(args[1].to_i32, args[2], args.process)
  end

  def waitfd(args : Syscall::Arguments)
    fds = checked_slice(Int32, args[0], args[1].to_i32) || return EINVAL
    timeout = args[2].to_u32

    if fds.size == 0
      return 0
    elsif fds.size == 1
      fd = args.process.udata.get_fd(fds[0]) || return EBADFD
      if fd.node.not_nil!.available? args.process
        return fds[0]
      end
      args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitFd
      args.process.udata.wait_object = fd
      args.process.udata.wait_usecs timeout
      Multiprocessing::Scheduler.switch_process(args.frame)
    end

    if waitfds = args.process.udata.wait_object.as?(Array(FileDescriptor))
      waitfds.clear
    else
      waitfds = Array(FileDescriptor).new fds.size
      args.process.udata.wait_object = waitfds
    end

    fds.each do |fdi|
      fd = args.process.udata.get_fd(fdi) || return EBADFD
      if fd.node.not_nil!.available? args.process
        waitfds.clear
        return fdi
      end
      waitfds.push fd
    end

    args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitFd
    args.process.udata.wait_usecs timeout
    Multiprocessing::Scheduler.switch_process(args.frame)
  end
end
