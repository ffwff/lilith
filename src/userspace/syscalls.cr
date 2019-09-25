require "./syscall_defs.cr"
require "./addr_sanitizer.cr"
require "./argv_builder.cr"

lib SyscallData
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
    stdin  : Int32
    stdout : Int32
    stderr : Int32
  end
end

lib Kernel
  fun ksyscall_sc_ret_driver(reg : SyscallData::Registers*) : NoReturn
end

module Syscall
  extend self

  def lock
    Idt.status_mask = true
    if Multiprocessing.current_process.not_nil!.kernel_process?
      DriverThread.unlock
    end
  end

  def unlock
    Idt.status_mask = false
    if Multiprocessing.current_process.not_nil!.kernel_process?
      DriverThread.lock
    end
  end

  # splits a path into segments separated by /
  private def parse_path_into_segments(path, &block)
    i = 0
    pslice_start = 0
    while i < path.size
      # Serial.puts path[i].unsafe_chr
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
  private def parse_path_into_vfs(path, cw_node = nil, create = false,
                             process : Multiprocessing::Process? = nil)
    vfs_node : VFSNode? = nil
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
        cur_node = vfs_node.open(segment)
        if cur_node.nil? && create
          cur_node = vfs_node.create(segment, process)
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
    if path[0] == '/'.ord
      vfs_node = nil
      cpath = GcString.new "/"
      idx = 0
    else
      vfs_node = cw_node
      cpath = GcString.new src_path
      idx = cpath.size
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
          while idx > 1
            idx -= 1
            if cpath[idx] == '/'.ord
              break
            end
          end
          vfs_node = vfs_node.not_nil!.parent
        end
      else
        cpath.insert(idx, '/'.ord.to_u8)
        idx += 1
        segment.each do |ch|
          cpath.insert(idx, ch)
          idx += 1
        end
        if vfs_node.nil?
          RootFS.each do |fs|
            if segment == fs.name
              # Serial.puts "goto ", fs.name, '\n'
              if (vfs_node = fs.root).nil?
                return nil
              else
                break
              end
            end
          end
        elsif (vfs_node = vfs_node.not_nil!.open(segment)).nil?
          # Serial.puts segment, '\n'
          return nil
        end
      end
    end

    Tuple.new(cpath, idx, vfs_node)
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
        return
      end
    end
  end

  # get syscall argument
  private macro arg(num)
    {% 
      arg_registers = [
        "rbx", "rdx", "rdi", "rsi"
      ]
    %}
    fv.{{ arg_registers[num].id }}
  end

  private macro sysret(num)
    fv.rax = {{ num }}
    return
  end

  @[AlwaysInline]
  def handler(frame : SyscallData::Registers*)
    process = Multiprocessing.current_process.not_nil!
    if process.kernel_process?
      case fv.rax
      when SC_MMAP_DRV
        virt_addr = fv.rbx
        fv.rax = Paging.alloc_page_pg(
          virt_addr, fv.rdx != 0, fv.r8 != 0,
          fv.r9
        )
        if virt_addr <= PDPT_SIZE && process.phys_user_pg_struct == 0u64
          process.phys_user_pg_struct = Paging.real_pdpt.address
        end
      when SC_PROCESS_CREATE_DRV
        initial_ip = fv.rbx
        heap_start = fv.rdx
        udata = Pointer(Void).new(fv.r8).as(Multiprocessing::Process::UserData)
        mmap_list = Slice(ElfReader::InlineMemMapNode).new(Pointer(ElfReader::InlineMemMapNode).new(fv.r9), fv.r10.to_i32)
        process = Multiprocessing::Process.spawn_user(initial_ip, heap_start, udata, mmap_list)
        fv.rax = process.pid
      when SC_SLEEP
        process.status = Multiprocessing::Process::Status::WaitIo
        Multiprocessing.switch_process(frame)
      else
        sysret(SYSCALL_ERR)
      end
      unlock
      return Kernel.ksyscall_sc_ret_driver(frame)
    end
    pudata = process.udata
    # Serial.puts "syscall ", fv.rax, " from ", process.pid, '\n'
    case fv.rax
    # files
    when SC_OPEN
      path = try(checked_slice(arg(0), arg(1)))
      vfs_node = parse_path_into_vfs path, pudata.cwd_node
      if vfs_node.nil?
        sysret(SYSCALL_ERR)
      else
        sysret(pudata.install_fd(vfs_node.not_nil!,
          FileDescriptor::Attributes.new(arg(2).to_i32)))
      end
    when SC_CREATE
      path = try(checked_slice(arg(0), arg(1)))
      vfs_node = parse_path_into_vfs path, pudata.cwd_node, true, process
      if vfs_node.nil?
        sysret(SYSCALL_ERR)
      else
        sysret(pudata.install_fd(vfs_node.not_nil!,
          FileDescriptor::Attributes::Read | FileDescriptor::Attributes::Write))
      end
    when SC_CLOSE
      if pudata.close_fd(arg(0).to_i32)
        sysret(SYSCALL_SUCCESS)
      else
        sysret(SYSCALL_ERR)
      end
    when SC_REMOVE
      path = try(checked_slice(arg(0), arg(1)))
      vfs_node = parse_path_into_vfs path, pudata.cwd_node
      if vfs_node.nil?
        sysret(SYSCALL_ERR)
      else
        sysret(vfs_node.remove)
      end
    when SC_READ
      fd = try(pudata.get_fd(arg(0).to_i32))
      if arg(2) == 0u64
        sysret(0)
      elsif !fd.attrs.includes?(FileDescriptor::Attributes::Read)
        sysret(SYSCALL_ERR)
      end
      str = try(checked_slice(arg(1), arg(2)))
      result = fd.not_nil!.node.not_nil!.read(str, fd.offset, process)
      case result
      when VFS_WAIT_NO_ENQUEUE
        process.status = Multiprocessing::Process::Status::WaitIo
        Multiprocessing.switch_process(frame)
      when VFS_WAIT
        vfs_node = fd.not_nil!.node.not_nil!
        vfs_node.fs.queue.not_nil!
          .enqueue(VFSMessage.new(VFSMessage::Type::Read,
            str, process, fd, vfs_node))
        process.status = Multiprocessing::Process::Status::WaitIo
        Multiprocessing.switch_process(frame)
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
      str = try(checked_slice(arg(1), arg(2)))
      result = fd.not_nil!.node.not_nil!.write(str, fd.offset, process)
      case result
      when VFS_WAIT_NO_ENQUEUE
        process.status = Multiprocessing::Process::Status::WaitIo
        Multiprocessing.switch_process(frame)
      when VFS_WAIT
        vfs_node = fd.not_nil!.node.not_nil!
        vfs_node.fs.queue.not_nil!
          .enqueue(VFSMessage.new(VFSMessage::Type::Write,
            str, process, fd, vfs_node))
        process.status = Multiprocessing::Process::Status::WaitIo
        return Multiprocessing.switch_process(frame)
      else
        if result > 0
          fd.offset += result
        end
        sysret(result)
      end
    when SC_TRUNCATE
      fd = try(pudata.get_fd(arg(0).to_i32))
      fv.rax = fd.node.not_nil!.truncate(arg(1).to_i32)
    when SC_SEEK
      fd = try(pudata.get_fd(arg(0).to_i32))  
      whence = arg(1)
      offset = arg(2).to_i32

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
        sysret(SYSCALL_ERR)
      end
    when SC_IOCTL
      fd = try(pudata.get_fd(arg(0).to_i32))
      sysret(fd.node.not_nil!.ioctl(arg(1).to_i32, arg(2).to_u32, process))
    when SC_WAITFD
      fds = try(checked_slice(Int32, arg(0), arg(1).to_i32))
      timeout = arg(2).to_u32
      
      if fds.size == 0
        sysret(0)
      elsif fds.size == 1
        fd = try(pudata.get_fd(fds[0]))
        process.status = Multiprocessing::Process::Status::WaitFd
        pudata.wait_object = fd
        pudata.wait_usecs = timeout
        Multiprocessing.switch_process(frame)
      end
      
      waitfds = GcArray(FileDescriptor).new 0
      fds.each do |fdi|
        fd = try(pudata.get_fd(fdi))
        if fd.node.not_nil!.available?
          sysret(fdi)
        end
        waitfds.push fd
      end
      
      process.status = Multiprocessing::Process::Status::WaitFd
      pudata.wait_object = waitfds
      pudata.wait_usecs = timeout
      Multiprocessing.switch_process(frame)
    # directories
    when SC_READDIR
      fd = try(pudata.get_fd(arg(0).to_i32))
      retval = try(checked_pointer(SyscallData::DirentArgument32, arg(1)))
      if fd.cur_child_end
        sysret(0)
      elsif fd.cur_child.nil?
        if (child = fd.node.not_nil!.first_child).nil?
          sysret(SYSCALL_ERR)
        end
        fd.cur_child = child
      end

      child = fd.cur_child.not_nil!

      dirent = SyscallData::DirentArgument32.new
      dirent.d_ino = 0
      dirent.d_reclen = sizeof(SyscallData::DirentArgument32)
      dirent.d_type = 0
      if (name = child.name).nil?
        dirent.d_name[0] = '/'.ord.to_u8
        dirent.d_name[1] = 0
      else
        name = name.not_nil!
        i = 0
        while i < min(name.size, dirent.d_name.size - 1)
          dirent.d_name[i] = name[i]
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
    # process management
    when SC_GETPID
      sysret(process.pid)
    when SC_SPAWN
      path = try(checked_slice(arg(0), arg(1)))
      startup_info = checked_pointer(SyscallData::SpawnStartupInfo32, arg(2))
      argv = try(checked_pointer(UInt32, arg(3)))

      # search in path env
      vfs_node = unless (path_env = pudata.getenv("PATH")).nil?
        # TODO: parse multiple paths
        unless (dir = parse_path_into_vfs(path_env)).nil?
          parse_path_into_vfs path, dir
        end
      end
      # search binary in cwd
      if vfs_node.nil?
        vfs_node = parse_path_into_vfs path, pudata.cwd_node
      end

      if vfs_node.nil?
        sysret(SYSCALL_ERR)
      else
        # argv
        pargv = GcArray(GcString).new 0
        i = 0
        while i < SC_SPAWN_MAX_ARGS
          if argv[i] == 0
            break
          end
          arg = NullTerminatedSlice.new(try(checked_pointer(UInt8, argv[i])))
          pargv.push GcString.new(arg, arg.size)
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
          if process.udata.fds[startup_info.value.stdin]?
            udata.fds[0] = process.udata.fds[startup_info.value.stdin].not_nil!.clone 0
          end
          if process.udata.fds[startup_info.value.stdin]?
            udata.fds[1] = process.udata.fds[startup_info.value.stdout].not_nil!.clone 1
          end
          if process.udata.fds[startup_info.value.stdin]?
            udata.fds[2] = process.udata.fds[startup_info.value.stderr].not_nil!.clone 2
          end
        else
          3.times do |i|
            if (fd = process.udata.fds[i])
              udata.fds[i] = fd.clone i
            end
            i += 1
          end
        end

        # create the process
        retval = vfs_node.not_nil!.spawn(udata)
        case retval
        when VFS_WAIT
          vfs_node.fs.queue.not_nil!
            .enqueue(VFSMessage.new(udata, vfs_node, process))
          process.status = Multiprocessing::Process::Status::WaitIo
          Multiprocessing.switch_process(frame)
        else
          sysret(retval)
        end
      end
    when SC_WAITPID
      pid = arg(0).to_i32
      # if fv.rdx != 0
      #   arg = try(checked_pointer(SyscallData::WaitPidArgument32, fv.rdx))
      # end
      if pid <= 0
        # wait for any child process
        Serial.puts "waitpid: pid <= 0 unimplemented"
        sysret(SYSCALL_ERR)
      else # pid > 0
        cprocess = nil
        Multiprocessing.each do |proc|
          if proc.pid == pid
            cprocess = proc
            break
          end
        end
        if cprocess.nil?
          sysret(SYSCALL_ERR)
        else
          fv.rax = pid
          process.status = Multiprocessing::Process::Status::WaitProcess
          pudata.wait_object = cprocess
          Multiprocessing.switch_process(frame)
        end
      end
    when SC_TIME
      lo = Time.stamp & 0xFFFF_FFFF
      hi = Time.stamp >> 32
      fv.rbx = hi
      sysret(lo)
    when SC_SLEEP
      timeout = fv.rbx.to_u32
      if timeout == 0
        return
      elsif timeout == 0xFFFF_FFFFu32
        process.status = Multiprocessing::Process::Status::WaitIo
      else
        process.status = Multiprocessing::Process::Status::Sleep
        pudata.wait_usecs = timeout
      end
      Multiprocessing.switch_process(frame)
    when SC_GETENV
      # TODO
    when SC_SETENV
      # TODO
    when SC_EXIT
      Multiprocessing.switch_process_and_terminate
    # working directory
    when SC_GETCWD
      str = try(checked_slice(arg(0), arg(1)))
      if str.size > PATH_MAX
        sysret(SYSCALL_ERR)
      end
      idx = 0
      pudata.cwd.each do |ch|
        break if idx == str.size - 1
        str[idx] = ch
        idx += 1
      end
      str[idx] = 0
      sysret(idx)
    when SC_CHDIR
      path = try(checked_slice(arg(0), arg(1)))
      if (t = append_paths path, pudata.cwd, pudata.cwd_node).nil?
        sysret(SYSCALL_ERR)
      else
        cpath, idx, vfs_node = t.not_nil!
        if !vfs_node.nil?
          pudata.cwd = GcString.new(cpath, idx)
          pudata.cwd_node = vfs_node.not_nil!
          sysret(SYSCALL_SUCCESS)
        else
          sysret(SYSCALL_ERR)
        end
      end
    # memory management
    when SC_SBRK
      incr = arg(0).to_i64
      # must be page aligned
      if (incr & 0xfff != 0) || pudata.mmap_heap.nil?
        sysret(SYSCALL_ERR)
      end
      mmap_heap = pudata.mmap_heap.not_nil!
      if incr > 0
        if !mmap_heap.next_node.nil?
          if mmap_heap.end_addr + incr >= mmap_heap.next_node.not_nil!.addr
            # out of virtual memory
            sysret(SYSCALL_ERR)
          end
        end
        npages = (incr >> 12) + 1
        Paging.alloc_page_pg(mmap_heap.end_addr, true, true, npages: npages.to_u64)
        mmap_heap.size += incr
      elsif incr == 0 && mmap_heap.size == 0u64
        if !mmap_heap.next_node.nil?
          if mmap_heap.end_addr + 0x1000 >= mmap_heap.next_node.not_nil!.addr
            # out of virtual memory
            sysret(SYSCALL_ERR)
          end
        end
        Paging.alloc_page_pg(mmap_heap.addr, true, true)
        mmap_heap.size += 0x1000
      elsif incr < 0
        # TODO
        panic "decreasing heap not implemented"
      end
      fv.rax = mmap_heap.addr
    else
      sysret(SYSCALL_ERR)
    end
  end
end

fun ksyscall_handler(frame : SyscallData::Registers*)
  Syscall.lock
  Syscall.handler frame
  Syscall.unlock
end
