require "./syscall_defs.cr"
require "./checked_pointers.cr"
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
    GC.needs_scan_kernel_stack = true
    Idt.switch_processes = false
    Idt.enable
  end

  def unlock
    @@locked = false
    GC.needs_scan_kernel_stack = false
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
        unless vfs_node = RootFS.find_root(segment)
          return
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
        cur_node = vfs_node.open_cached?(segment) ||
                   vfs_node.open(segment, process)
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
          unless vfs_node = RootFS.find_root(segment)
            return
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

  def handler(frame : Syscall::Data::Registers*)
    process = Multiprocessing::Scheduler.current_process.not_nil!
    args = Syscall::Arguments.new frame, process

    # syscall handlers for kernel processes
    if process.kernel_process?
      {% for syscall %w(mmap_drv process_create_drv) %}
        if frame.value.rax == SC_{{ syscall.upper }}
          if retval = Syscall::Handlers.{{ syscall }} args
            frame.value.rax = retval
          end
          return Kernel.ksyscall_sc_ret_driver(frame)
        end
      {% end %}
      abort "unknown kernel syscall!"
    end

    # syscall handlers for user processes
    {% for syscall in %w(open read write fattr spawn close exit
                         seek getcwd chdir sbrk readdir waitpid
                         ioctl mmap time sleep getenv setenv create
                         truncate waitfd remove munmap) %}
      if frame.value.rax == SC_{{ syscall.upper }}
        if retval = Syscall::Handlers.{{ syscall }} args
          frame.value.rax = retval
        end
        return
      end
    {% end %}
    frame.value.rax = EINVAL
  end
end

fun ksyscall_handler(frame : Syscall::Data::Registers*)
  Syscall.lock
  Syscall.handler frame
  Syscall.unlock
end
