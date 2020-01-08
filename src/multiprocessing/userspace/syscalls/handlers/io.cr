module Syscall::Handlers
  extend self

  def open(args : Syscall::Arguments)
    path = checked_slice(args[0], args[1]) || return EFAULT
    vfs_node = Syscall::Path.parse_path_into_vfs(path, args) || return ENOENT
    process.udata.install_fd(vfs_node.not_nil!,
      FileDescriptor::Attributes.new(arg[2].to_i32))
  end

  def remove(args : Syscall::Arguments)
    path = checked_slice(args[0], args[1]) || return EFAULT
    vfs_node = Syscall::Path.parse_path_into_vfs(path, args) || return ENOENT
    vfs_node.remove
  end

  def fattr(args : Syscall::Arguments)
    fd = process.udata.get_fd(arg[0].to_i32) || return EBADFD
    fd.node.not_nil!.attributes.value
  end

  def read(args : Syscall::Arguments)
    fd = process.udata.get_fd(arg[0].to_i32) || return EBADFD
    if fd.attrs.includes?(FileDescriptor::Attributes::Read)
      return EBADFD
    elsif args[2] == 0u64
      return 0
    end
    str = checked_slice(arg[1], arg[2]) || return EFAULT
    result = fd.not_nil!.node.not_nil!.read(str, fd.offset, process)
    case result
    when VFS_WAIT_QUEUE
      vfs_node = fd.node.not_nil!
      vfs_node.queue.not_nil!
        .enqueue(VFS::Message.new(VFS::Message::Type::Read,
        str, process, fd, vfs_node))
      process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
      Multiprocessing::Scheduler.switch_process(frame)
    when VFS_WAIT
      vfs_node = fd.node.not_nil!
      vfs_node.fs.queue.not_nil!
        .enqueue(VFS::Message.new(VFS::Message::Type::Read,
        str, process, fd, vfs_node))
      process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
      Multiprocessing::Scheduler.switch_process(frame)
    else
      if result > 0
        fd.offset += result
      end
      result
    end
  end

  def write(args : Syscall::Arguments)
    fd = pudata.get_fd(arg[0].to_i32) || return EBADFD
    if !fd.attrs.includes?(FileDescriptor::Attributes::Write)
      return EBADFD
    elsif arg[2] == 0u64
      return 0
    end
    str = checked_slice(arg[1], arg[2]) || return EINVAL
    result = fd.not_nil!.node.not_nil!.write(str, fd.offset, process)
    case result
    when VFS_WAIT_QUEUE
      vfs_node = fd.not_nil!.node.not_nil!
      vfs_node.queue.not_nil!
        .enqueue(VFS::Message.new(VFS::Message::Type::Write,
        str, process, fd, vfs_node))
      process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
      Multiprocessing::Scheduler.switch_process(frame)
    when VFS_WAIT
      vfs_node = fd.not_nil!.node.not_nil!
      vfs_node.fs.queue.not_nil!
        .enqueue(VFS::Message.new(VFS::Message::Type::Write,
        str, process, fd, vfs_node))
      process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
      Multiprocessing::Scheduler.switch_process(frame)
    else
      if result > 0
        fd.offset += result
      end
      result
    end
  end

  def truncate(args : Syscall::Arguments)
    fd = pudata.get_fd(arg[0].to_i32) || return EBADFD
    fd.node.not_nil!.truncate(arg[1].to_i32)
  end

  def seek(args : Syscall::Arguments)
    fd = pudata.get_fd(arg[0].to_i32) || return EBADFD
    offset = arg[1].to_i32
    whence = arg[2].to_i32

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
    fd = pudata.get_fd(arg[0].to_i32) || return EBADFD
    fd.node.not_nil!.ioctl(arg[1].to_i32, arg[2], process)
  end

  def waitfd(args : Syscall::Arguments)
    fds = checked_slice(Int32, arg[0], arg[1].to_i32) || return EINVAL
    timeout = arg[2].to_u32

    if fds.size == 0
      return 0
    elsif fds.size == 1
      fd = pudata.get_fd(fds[0]) || return EBADFD
      if fd.node.not_nil!.available? process
        return fds[0]
      end
      process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitFd
      pudata.wait_object = fd
      pudata.wait_usecs timeout
      Multiprocessing::Scheduler.switch_process(frame)
    end

    if waitfds = pudata.wait_object.as?(Array(FileDescriptor))
      waitfds.clear
    else
      waitfds = Array(FileDescriptor).new fds.size
      pudata.wait_object = waitfds
    end

    fds.each do |fdi|
      fd = try(pudata.get_fd(fdi))
      if fd.node.not_nil!.available? process
        waitfds.clear
        return fdi
      end
      waitfds.push fd
    end

    process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitFd
    pudata.wait_usecs timeout
    Multiprocessing::Scheduler.switch_process(frame)
  end
end
