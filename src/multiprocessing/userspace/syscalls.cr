require "./syscall_defs.cr"
require "./addr_sanitizer.cr"
require "./argv_builder.cr"

lib Kernel
  fun ksyscall_sc_ret_driver(reg : Syscall::Data::Registers*) : NoReturn
end

module Syscall
  extend self

  lib Data
    struct Registers
      ds : UInt64
      rbp, rdi, rsi,
r15, r14, r13, r12, r11, r10, r9, r8,
rdx, rcx, rbx, rax : UInt64
      rsp : UInt64
    end

    alias Ino32 = Int32

    @[Packed]
    struct DirentArgument32
      # Inode number
      d_ino : Ino32
      # Length of this record
      d_reclen : UInt16
      # Type of file; not supported by all filesystem types
      d_type : UInt8
      # Null-terminated filename
      d_name : UInt8[256]
    end

    @[Packed]
    struct SpawnStartupInfo32
      stdin : Int32
      stdout : Int32
      stderr : Int32
    end

    @[Flags]
    enum MmapProt : Int32
      Read    = 1 << 0
      Write   = 1 << 1
      Execute = 1 << 2
    end
  end

  @@locked = false
  class_getter locked

  def lock
    # NOTE: we disable process switching because
    # other processes might do another syscall
    # while the current syscall is still being processed
    @@locked = true
    Idt.switch_processes = false
    Idt.enable
  end

  def unlock
    @@locked = false
    Idt.switch_processes = true
    Idt.disable
  end

  # splits a path into segments separated by /
  private def parse_path_into_segments(path, &block)
    i = 0
    pslice_start = 0
    while i < path.size
      # Serial.print path[i].unsafe_chr
      if path[i] == '/'.ord
        # ignore multi occurences of slashes
        if i - pslice_start > 0
          # search for root subsystems
          yield path[pslice_start..i]
        end
        pslice_start = i + 1
      else
      end
      i += 1
    end
    if path.size - pslice_start > 0
      yield path[pslice_start..path.size]
    end
  end

  # parses a path and returns the corresponding vfs node
  private def parse_path_into_vfs(path : Slice(UInt8),
                                  process : Multiprocessing::Process,
                                  frame : Data::Registers*,
                                  cw_node = nil,
                                  create = false,
                                  create_options = 0)
    vfs_node : VFS::Node? = nil
    return nil if path.size < 1
    if path[0] != '/'.ord
      vfs_node = cw_node
    end
    parse_path_into_segments(path) do |segment|
      if vfs_node.nil? # no path specifier
        RootFS.each do |fs|
          if segment == fs.name
            if (vfs_node = fs.root).nil?
              return nil
            else
              break
            end
          end
        end
      elsif segment == "."
        # ignored
      elsif segment == ".."
        vfs_node = vfs_node.parent
      else
        if vfs_node.directory? && !vfs_node.dir_populated
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
        cur_node = vfs_node.open(segment, process)
        if cur_node.nil? && create
          cur_node = vfs_node.create(segment, process, create_options)
        end
        return if cur_node.nil?
        vfs_node = cur_node
      end
    end
    vfs_node
  end

  # append two path slices together
  private def append_paths(path, src_path, cw_node)
    return nil if path.size < 1
    builder = String::Builder.new

    if path[0] == '/'.ord
      vfs_node = nil
      builder << "/"
    else
      vfs_node = cw_node
      builder << src_path
    end

    parse_path_into_segments(path) do |segment|
      if segment == "."
        # ignored
      elsif segment == ".."
        # pop
        if !vfs_node.nil?
          if vfs_node.not_nil!.parent.nil?
            return nil
          end
          while builder.bytesize > 1
            builder.back 1
            if builder.buffer[builder.bytesize] == '/'.ord
              break
            end
          end
          vfs_node = vfs_node.not_nil!.parent
        end
      else
        builder << "/"
        builder << segment
        if vfs_node.nil?
          RootFS.each do |fs|
            if segment == fs.name
              # Serial.print "goto ", fs.name, '\n'
              if (vfs_node = fs.root).nil?
                return nil
              else
                break
              end
            end
          end
        elsif (vfs_node = vfs_node.not_nil!.open(segment)).nil?
          return nil
        end
      end
    end

    {builder.to_s, vfs_node}
  end

  # quick way to dereference a frame
  private macro fv
    frame.value
  end

  # try and check if expr is nil
  # if it is nil, set syscall return to SYSCALL_ERR
  # if it's not nil, return expr.not_nil!
  private macro try(expr)
    begin
      if !(x = {{ expr }}).nil?
        x.not_nil!
      else
        sysret(SYSCALL_ERR)
      end
    end
  end

  # try and check if expr is nil
  # if it is nil, set syscall return to error
  # if it's not nil, return expr.not_nil!
  private macro try(expr, err)
    begin
      if !(x = {{ expr }}).nil?
        x.not_nil!
      else
        sysret({{ err }})
      end
    end
  end

  # get syscall argument
  private macro arg(num)
    {%
      arg_registers = [
        "rbx", "rdx", "rdi", "rsi", "r8",
      ]
    %}
    fv.{{ arg_registers[num].id }}
  end

  private macro sysret(num)
    fv.rax = {{ num }}
    return
  end

  @[AlwaysInline]
  def handler(frame : Syscall::Data::Registers*)
    process = Multiprocessing::Scheduler.current_process.not_nil!
    # Serial.print "syscall ", fv.rax, " from ", Multiprocessing::Scheduler.current_process.not_nil!.pid, "\n"

    # syscall handlers for kernel processes
    if process.kernel_process?
      case fv.rax
      when SC_MMAP_DRV
        virt_addr = fv.rbx
        fv.rax = Paging.alloc_page_pg(
          virt_addr, fv.rdx != 0, fv.r8 != 0,
          fv.r9,
          execute: fv.r10 != 0
        )
        if virt_addr <= Paging::PDPT_SIZE && process.phys_user_pg_struct == 0u64
          process.phys_user_pg_struct = Paging.real_pdpt.address
        end
      when SC_PROCESS_CREATE_DRV
        result = Pointer(ElfReader::Result).new(fv.rbx)
        udata = Pointer(Void).new(fv.rdx).as(Multiprocessing::Process::UserData)
        Idt.disable do
          process = Multiprocessing::Process.spawn_user(udata, result.value)
        end
        fv.rax = process.pid
      when SC_SLEEP
        process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
        Multiprocessing::Scheduler.switch_process(frame)
      else
        panic "unknown syscall!"
      end
      unlock
      return Kernel.ksyscall_sc_ret_driver(frame)
    end

    # syscall handlers for userspace processes
    pudata = process.udata
    case fv.rax
    when SC_OPEN
      path = try(checked_slice(arg(0), arg(1)), EFAULT)
      vfs_node = try(parse_path_into_vfs(path, process, frame, pudata.cwd_node), ENOENT)
      sysret(pudata.install_fd(vfs_node.not_nil!,
        FileDescriptor::Attributes.new(arg(2).to_i32)))
    when SC_CREATE
      path = try(checked_slice(arg(0), arg(1)), EFAULT)
      options = arg(2).to_i32
      vfs_node = try(parse_path_into_vfs(path, process, frame, pudata.cwd_node, true, create_options: options), ENOENT)
      sysret(pudata.install_fd(vfs_node.not_nil!,
        FileDescriptor::Attributes.new(options)))
    when SC_CLOSE
      if pudata.close_fd(arg(0).to_i32)
        sysret(SYSCALL_SUCCESS)
      else
        sysret(SYSCALL_ERR)
      end
    when SC_REMOVE
      path = try(checked_slice(arg(0), arg(1)))
      vfs_node = try(parse_path_into_vfs(path, process, frame, pudata.cwd_node), ENOENT)
      sysret(vfs_node.remove)
    when SC_FATTR
      fd = try(pudata.get_fd(arg(0).to_i32), EBADFD)
      sysret(fd.node.not_nil!.attributes.value)
    when SC_READ
      fd = try(pudata.get_fd(arg(0).to_i32), EBADFD)
      if arg(2) == 0u64
        sysret(0)
      elsif !fd.attrs.includes?(FileDescriptor::Attributes::Read)
        sysret(EBADFD)
      end
      str = try(checked_slice(arg(1), arg(2)), EFAULT)
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
        sysret(result)
      end
    when SC_WRITE
      fd = try(pudata.get_fd(arg(0).to_i32))
      if arg(2) == 0u64
        sysret(0)
      elsif !fd.attrs.includes?(FileDescriptor::Attributes::Write)
        sysret(SYSCALL_ERR)
      end
      str = try(checked_slice(arg(1), arg(2)), EINVAL)
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
        sysret(result)
      end
    when SC_TRUNCATE
      fd = try(pudata.get_fd(arg(0).to_i32), EBADFD)
      fv.rax = fd.node.not_nil!.truncate(arg(1).to_i32)
    when SC_SEEK
      fd = try(pudata.get_fd(arg(0).to_i32), EBADFD)
      offset = arg(1).to_i32
      whence = arg(2).to_i32

      case whence
      when SC_SEEK_SET
        fd.offset = offset.to_u32
        sysret(fd.offset)
      when SC_SEEK_CUR
        fd.offset += offset
        sysret(fd.offset)
      when SC_SEEK_END
        fd.offset = (fd.node.not_nil!.size.to_i32 + offset).to_u32
        sysret(fd.offset)
      else
        sysret(EINVAL)
      end
    when SC_IOCTL
      fd = try(pudata.get_fd(arg(0).to_i32), EBADFD)
      sysret(fd.node.not_nil!.ioctl(arg(1).to_i32, arg(2), process))
    when SC_WAITFD
      fds = try(checked_slice(Int32, arg(0), arg(1).to_i32), EINVAL)
      timeout = arg(2).to_u32

      if fds.size == 0
        sysret(0)
      elsif fds.size == 1
        fd = try(pudata.get_fd(fds[0]))
        if fd.node.not_nil!.available? process
          sysret(fds[0])
        end
        process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitFd
        pudata.wait_object = fd
        pudata.wait_usecs timeout
        Multiprocessing::Scheduler.switch_process(frame)
      end

      waitfds = Array(FileDescriptor).build(fds.size) do |buffer|
        idx = 0
        fds.each do |fdi|
          fd = try(pudata.get_fd(fdi))
          if fd.node.not_nil!.available? process
            sysret(fdi)
          end
          buffer[idx] = fd
          idx += 1
        end
        fds.size
      end

      process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitFd
      pudata.wait_object = waitfds
      pudata.wait_usecs timeout
      Multiprocessing::Scheduler.switch_process(frame)
    when SC_READDIR
      fd = try(pudata.get_fd(arg(0).to_i32), EBADFD)
      retval = try(checked_pointer(Syscall::Data::DirentArgument32, arg(1)), EFAULT)
      if fd.cur_child_end
        sysret(0)
      elsif fd.cur_child.nil?
        if (child = fd.node.not_nil!.first_child).nil?
          sysret(ENOENT)
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
      sysret(SYSCALL_SUCCESS)
    when SC_SPAWN
      path = try(checked_slice(arg(0), arg(1)))
      sysret(EINVAL) if path.size < 1
      startup_info = checked_pointer(Syscall::Data::SpawnStartupInfo32, arg(2))
      if pudata.is64
        argv = try(checked_pointer(UInt64, arg(3)), EFAULT)
      else
        argv = try(checked_pointer(UInt32, arg(3)), EFAULT)
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
        sysret(ENOENT)
      else
        # argv
        pargv = Array(String).new 0
        i = 0
        while i < SC_SPAWN_MAX_ARGS
          if argv[i] == 0
            break
          end
          # FIXME: check for size of NullTerminatedSlice
          arg = NullTerminatedSlice.new(try(checked_pointer(UInt8, argv[i]), EFAULT))
          pargv.push String.new(arg)
          i += 1
        end

        udata = Multiprocessing::Process::UserData
          .new(pargv,
            pudata.cwd.clone,
            pudata.cwd_node,
            pudata.environ.clone)
        udata.pgid = pudata.pgid

        # copy file descriptors 0, 1, 2
        if !startup_info.nil?
          startup_info = startup_info.not_nil!
          if (fd = process.udata.fds[startup_info.value.stdin]?)
            udata.fds.push fd.clone(0)
          else
            udata.fds.push nil
          end
          if (fd = process.udata.fds[startup_info.value.stdout]?)
            udata.fds.push fd.clone(1)
          else
            udata.fds.push nil
          end
          if (fd = process.udata.fds[startup_info.value.stderr]?)
            udata.fds.push fd.clone(2)
          else
            udata.fds.push nil
          end
        else
          3.times do |i|
            if (fd = process.udata.fds[i])
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
            .enqueue(VFS::Message.new(udata, vfs_node, process))
          process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
          Multiprocessing::Scheduler.switch_process(frame)
        else
          sysret(retval)
        end
      end
    when SC_WAITPID
      pid = arg(0).to_i32
      if pid <= 0
        # wait for any child process
        Serial.print "waitpid: pid <= 0 unimplemented"
        sysret(EINVAL)
      else # pid > 0
        cprocess = nil
        Multiprocessing.each do |proc|
          if proc.pid == pid
            cprocess = proc
            break
          end
        end
        if cprocess.nil?
          sysret(EINVAL)
        else
          fv.rax = pid
          process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitProcess
          pudata.wait_object = cprocess
          Multiprocessing::Scheduler.switch_process(frame)
        end
      end
    when SC_TIME
      if pudata.is64
        sysret(Time.stamp)
      else
        lo = Time.stamp & 0xFFFF_FFFF
        hi = Time.stamp >> 32
        fv.rbx = hi
        sysret(lo)
      end
    when SC_SLEEP
      hi = arg(0).to_u32
      lo = arg(1).to_u32
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
    when SC_GETENV
      # TODO
    when SC_SETENV
      # TODO
    when SC_EXIT
      Multiprocessing::Scheduler.switch_process_and_terminate
    when SC_GETCWD
      if arg(0) == 0
        sysret(pudata.cwd.size)
      end
      str = try(checked_slice(arg(0), arg(1)))
      if str.size > SC_PATH_MAX
        sysret(EINVAL)
      end
      idx = 0
      pudata.cwd.each_byte do |ch|
        break if idx == str.size - 1
        str[idx] = ch
        idx += 1
      end
      str[idx] = 0
      sysret(idx)
    when SC_CHDIR
      path = try(checked_slice(arg(0), arg(1)))
      if (t = append_paths path, pudata.cwd, pudata.cwd_node).nil?
        sysret(ENOENT)
      else
        cwd, vfs_node = t.not_nil!
        if !vfs_node.nil?
          pudata.cwd = cwd
          pudata.cwd_node = vfs_node.not_nil!
          sysret(SYSCALL_SUCCESS)
        else
          sysret(EINVAL)
        end
      end
    when SC_SBRK
      incr = arg(0).to_i64
      # must be page aligned
      if (incr & 0xfff != 0) || pudata.mmap_heap.nil?
        sysret(EINVAL)
      end
      mmap_heap = pudata.mmap_heap.not_nil!
      if incr > 0
        if !mmap_heap.next_node.nil?
          if mmap_heap.end_addr + incr >= mmap_heap.next_node.not_nil!.addr
            # out of virtual memory
            sysret(EINVAL)
          end
        end
        npages = incr // 0x1000
        Paging.alloc_page_pg(mmap_heap.end_addr, true, true, npages: npages.to_u64)
        pudata.memory_used += incr // 1024
        mmap_heap.size += incr
      elsif incr == 0 && mmap_heap.size == 0u64
        if !mmap_heap.next_node.nil?
          if mmap_heap.end_addr + 0x1000 >= mmap_heap.next_node.not_nil!.addr
            # out of virtual memory
            sysret(EINVAL)
          end
        end
        Paging.alloc_page_pg(mmap_heap.addr, true, true)
        pudata.memory_used += (0x1000 // 1024)
        mmap_heap.size += 0x1000
      elsif incr < 0
        # TODO
        panic "decreasing heap not implemented"
      end
      fv.rax = mmap_heap.addr
    when SC_MMAP
      fdi = arg(0).to_i32

      prot = Syscall::Data::MmapProt.new(arg(1).to_i32)
      mmap_attrs = MemMapNode::Attributes::Read
      if prot.includes?(Syscall::Data::MmapProt::Write)
        mmap_attrs |= MemMapNode::Attributes::Write
      end
      if prot.includes?(Syscall::Data::MmapProt::Execute)
        mmap_attrs |= MemMapNode::Attributes::Execute
      end

      addr = arg(3)
      size = arg(4)

      if fdi == -1
        if (size & 0xfff) != 0
          sysret(0)
        end
        Paging.alloc_page_pg addr,
          mmap_attrs.includes?(MemMapNode::Attributes::Write),
          true, size // 0x1000
        pudata.memory_used += size // 1024
        pudata.mmap_list.add(addr, size, mmap_attrs)
        sysret(addr)
      else
        mmap_attrs |= MemMapNode::Attributes::SharedMem
        fd = try(pudata.get_fd(fdi))
        if size > fd.node.not_nil!.size
          size = fd.node.not_nil!.size.to_u64
          if (size & 0xfff) != 0
            size = (size & 0xFFFF_F000) + 0x1000
          end
        end
        mmap_node = pudata.mmap_list.space_for_mmap process, size, mmap_attrs
        if mmap_node
          if (retval = fd.node.not_nil!.mmap(mmap_node, process)) == VFS_OK
            mmap_node.shm_node = fd.node
            sysret(mmap_node.addr)
          else
            pudata.mmap_list.remove mmap_node
            sysret(0)
          end
        else
          sysret(0)
        end
      end
    when SC_MUNMAP
      # TODO: support size argument
      addr = arg(0)
      pudata.mmap_list.each do |node|
        if node.addr == addr && node.attr.includes?(MemMapNode::Attributes::SharedMem)
          node.shm_node.not_nil!.munmap(node, process)
          pudata.mmap_list.remove(node)
          sysret(0)
        end
      end
    else
      sysret(EINVAL)
    end
  end
end

fun ksyscall_handler(frame : Syscall::Data::Registers*)
  Syscall.lock
  Syscall.handler frame
  Syscall.unlock
end
