require "../drivers/cpumsr.cr"
require "./syscall_defs.cr"

lib SyscallData

    @[Packed]
    struct Registers
        # Pushed by pushad:
        # ecx is unused
        edi, esi, ebp, esp, ebx, edx, ecx, eax : UInt32
    end

    struct SyscallStringArgument
        str : UInt32
        len : Int32
    end

    struct SyscallSeekArgument
        offset : Int32
        whence : UInt32
    end

end

# checked inputs
private def checked_pointer(addr : UInt32) : Void* | Nil
    if addr < 0x8000_0000
        nil
    else
        Pointer(Void).new(addr.to_u64)
    end
end

private def checked_slice(addr : UInt32, len : Int32) : Slice(UInt8) | Nil
    end_addr = addr + len
    if addr < 0x8000_0000 || end_addr < 0x8000_0000
        nil
    else
        Slice(UInt8).new(Pointer(UInt8).new(addr.to_u64), len.to_i32)
    end
end

# path parser
private def parse_path_into_segments(path, &block)
    i = 0
    pslice_start = 0
    while i < path.size
        #Serial.puts path[i].unsafe_chr
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

private def parse_path_into_vfs(path, cwnode=nil)
    vfs_node : VFSNode | Nil = nil
    return nil if path.size < 1
    if path[0] != '/'.ord
        vfs_node = cwnode
    end
    parse_path_into_segments(path) do |segment|
        if vfs_node.nil? # no path specifier
            ROOTFS.each do |fs|
                if segment == fs.name
                    node = fs.root
                    if node.nil?
                        return nil
                    else
                        vfs_node = node
                        break
                    end
                end
            end
        elsif segment == "."
            # ignored
        elsif segment == ".."
            vfs_node = vfs_node.parent
        else
            vfs_node = vfs_node.open(segment)
        end
    end
    vfs_node
end

private def canonicalize_path(path)
    cpath = uninitialized UInt8[PATH_MAX]
    cpath[0] = '/'
    idx = 1
    parse_path_into_segments(path) do |segment|
        if segment == "."
            # ignored
        elsif segment == ".."
            # pop
            while idx > 1
                idx -= 1
                break if path[idx] == '/'
            end
        else
            cpath[idx] = '/'
            idx += 1
            segment.each do |ch|
                cpath[idx] = ch
                idx += 1
            end
        end
    end
end

private macro try(expr)
    begin
        if !(x = {{ expr }}).nil?
            x.not_nil!
        else
            frame.eax = SYSCALL_ERR
            return
        end
    end
end

fun ksyscall_handler(frame : SyscallData::Registers)
    process = Multiprocessing.current_process.not_nil!
    case frame.eax
    # files
    when SC_OPEN
        path = NullTerminatedSlice.new(try(checked_pointer(frame.ebx)).as(UInt8*))
        vfs_node = parse_path_into_vfs path, process.cwd_node
        if vfs_node.nil?
            frame.eax = SYSCALL_ERR
        else
            frame.eax = process.install_fd(vfs_node.not_nil!)
        end
    when SC_READ
        fdi = frame.ebx.to_i32
        fd = try(process.get_fd(fdi))
        arg = try(checked_pointer(frame.edx)).as(SyscallData::SyscallStringArgument*)
        str = try(checked_slice(arg.value.str, arg.value.len))
        result = fd.not_nil!.node.not_nil!.read(str, fd.offset, process)
        case result
        when VFS_READ_WAIT
            process.new_frame frame
            fd.not_nil!.node.not_nil!.read_queue.not_nil!.push(VFSReadMessage.new(str, process))
            process.status = Multiprocessing::ProcessStatus::ReadWait
            Multiprocessing.switch_process(nil)
        else
            frame.eax = result
        end
    when SC_WRITE
        fdi = frame.ebx.to_i32
        fd = try(process.get_fd(fdi))
        arg = try(checked_pointer(frame.edx)).as(SyscallData::SyscallStringArgument*)
        str = try(checked_slice(arg.value.str, arg.value.len))
        frame.eax = fd.not_nil!.node.not_nil!.write(str)
    when SC_SEEK
        fdi = frame.ebx.to_i32
        fd = try(process.get_fd(fdi))
        arg = try(checked_pointer(frame.edx)).as(SyscallData::SyscallSeekArgument*)

        case arg.value.whence
        when SC_SEEK_SET
            fd.offset = arg.value.offset.to_u32
            frame.eax = fd.offset
        when SC_SEEK_CUR
            fd.offset += arg.value.offset
            frame.eax = fd.offset
        when SC_SEEK_END
            fd.offset = (fd.node.not_nil!.size.to_i32 + arg.value.offset).to_u32
            frame.eax = fd.offset
        else
            frame.eax = SYSCALL_ERR
        end
    when SC_CLOSE
        fdi = frame.ebx.to_i32
        if process.close_fd(fdi)
            frame.eax = SYSCALL_SUCCESS
        else
            frame.eax = SYSCALL_ERR
        end
    # process management
    when SC_GETPID
        frame.eax = process.pid
    when SC_SPAWN
        path = NullTerminatedSlice.new(try(checked_pointer(frame.ebx)).as(UInt8*))
        vfs_node = parse_path_into_vfs path, process.cwd_node
        if vfs_node.nil?
            frame.eax = SYSCALL_ERR
        else
            Idt.status_mask = true
            new_process = Multiprocessing::Process.new do |proc|
                ElfReader.load(proc, vfs_node.not_nil!)
            end
            new_process.cwd = process.cwd #TODO: clone string buffer
            new_process.cwd_node = process.cwd_node
            Idt.status_mask = false
            frame.eax = 1
        end
    when SC_EXIT
        Multiprocessing.switch_process(nil, true)
    when SC_GETCWD
        arg = try(checked_pointer(frame.ebx)).as(SyscallData::SyscallStringArgument*)
        if arg.value.len > PATH_MAX
            frame.eax = SYSCALL_ERR
            return
        end
        str = try(checked_slice(arg.value.str, arg.value.len))
        idx = 0
        process.cwd.each_char do |ch|
            break if idx == str.size
            str[idx] = ch
            idx += 1
        end
        str[idx] = 0
        frame.eax = idx
    when SC_CHDIR
    # memory management
    when SC_SBRK
        incr = frame.ebx.to_i32
        Serial.puts "sbrk: ", incr, "\n"
        if incr == 0
            # return the end of the heap if incr = 0
            if process.heap_end == 0
                # there are no pages allocated for program heap
                Idt.status_mask = true
                process.heap_end = Paging.alloc_page_pg(process.heap_start, true, true)
                Idt.status_mask = false
            end
        elsif incr > 0
            # increase the end of the heap if incr > 0
            heap_end_a = Paging.aligned(process.heap_end)
            npages = ((process.heap_end + incr) - heap_end_a).unsafe_shr(12) + 1
            if npages > 0
                Idt.status_mask = true
                Paging.alloc_page_pg(process.heap_end, true, true, npages: npages)
                Idt.status_mask = false
            end
        else
            panic "decreasing heap not implemented"
        end
        frame.eax = process.heap_end
        process.heap_end += incr
    else
        frame.eax = SYSCALL_ERR
    end
end