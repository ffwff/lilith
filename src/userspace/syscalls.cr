require "../drivers/cpumsr.cr"

lib SyscallData

    @[Packed]
    struct Registers
        # Pushed by pushad:
        # ecx is unused
        edi, esi, ebp, esp, ebx, edx, ecx_, eax : UInt32
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

# consts
SYSCALL_ERR = (~0).to_u32
SYSCALL_SUCCESS = 1u32

SC_OPEN   = 0u32
SC_READ   = 1u32
SC_WRITE  = 2u32
SC_GETPID = 3u32
SC_SPAWN  = 4u32
SC_CLOSE  = 5u32
SC_EXIT   = 6u32
SC_SEEK   = 7u32

SC_SEEK_SET = 0u32
SC_SEEK_CUR = 1u32
SC_SEEK_END = 2u32

private macro try!(expr)
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
    case frame.eax
    # files
    when SC_OPEN
        path = NullTerminatedSlice.new(try!(checked_pointer(frame.ebx)).as(UInt8*))
        vfs_node : VFSNode | Nil = nil
        parse_path_into_segments(path) do |segment|
            if vfs_node.nil? # no path specifier
                ROOTFS.each do |fs|
                    if segment == fs.name
                        node = fs.root
                        if node.nil?
                            frame.eax = SYSCALL_ERR
                            return
                        else
                            vfs_node = node
                            break
                        end
                    end
                end
            else
                vfs_node = vfs_node.open(segment)
            end
        end
        if vfs_node.nil?
            frame.eax = SYSCALL_ERR
        else
            frame.eax = Multiprocessing.current_process.not_nil!.install_fd(vfs_node.not_nil!)
        end
    when SC_READ
        fdi = frame.ebx.to_i32
        fd = try!(Multiprocessing.current_process.not_nil!.get_fd(fdi))
        arg = try!(checked_pointer(frame.edx)).as(SyscallData::SyscallStringArgument*)
        str = try!(checked_slice(arg.value.str, arg.value.len))
        frame.eax = fd.not_nil!.node.not_nil!.read(str, fd.offset)
    when SC_WRITE
        fdi = frame.ebx.to_i32
        fd = try!(Multiprocessing.current_process.not_nil!.get_fd(fdi))
        arg = try!(checked_pointer(frame.edx)).as(SyscallData::SyscallStringArgument*)
        str = try!(checked_slice(arg.value.str, arg.value.len))
        frame.eax = fd.not_nil!.node.not_nil!.write(str)
    when SC_SEEK
        fdi = frame.ebx.to_i32
        fd = try!(Multiprocessing.current_process.not_nil!.get_fd(fdi))
        arg = try!(checked_pointer(frame.edx)).as(SyscallData::SyscallSeekArgument*)

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
        if Multiprocessing.current_process.not_nil!.close_fd(fdi)
            frame.eax = SYSCALL_SUCCESS
        else
            frame.eax = SYSCALL_ERR
        end
    # process management
    when SC_GETPID
        frame.eax = Multiprocessing.current_process.not_nil!.pid
    when SC_SPAWN
        path = NullTerminatedSlice.new(try!(checked_pointer(frame.ebx)).as(UInt8*))
        vfs_node = nil
        parse_path_into_segments(path) do |segment|
            if vfs_node.nil? # no path specifier
                ROOTFS.each do |fs|
                    if segment == fs.name
                        node = fs.root
                        if node.nil?
                            frame.eax = SYSCALL_ERR
                            return
                        else
                            vfs_node = node
                            break
                        end
                    end
                end
            else
                vfs_node = vfs_node.open(segment)
            end
        end
        #
        if vfs_node.nil?
            frame.eax = SYSCALL_ERR
        else
            Idt.status_mask = true
            process = Multiprocessing::Process.new do |proc|
                ElfReader.load(proc, vfs_node.not_nil!)
            end
            Idt.status_mask = false
            frame.eax = 1
        end
    when SC_EXIT
        if Multiprocessing.n_process == 1
            panic "init exited"
        end

        current_process = Multiprocessing.current_process.not_nil!
        current_page_dir = current_process.phys_page_dir
        next_process = Multiprocessing.next_process.not_nil!
        current_process.remove

        # switch to next process
        Multiprocessing.current_process = next_process

        # next
        if next_process.frame.nil?
            next_process.new_frame
        end

        # load process's state
        process_frame = next_process.frame.not_nil!
        memcpy Multiprocessing.fxsave_region, next_process.fxsave_region.ptr, 512

        # use new process page dir
        dir = next_process.not_nil!.phys_page_dir # this must be stack allocated
        # because it's placed in the virtual kernel heap
        panic "page dir is nil" if dir == 0
        Paging.disable
        Paging.free_process_page_dir(current_page_dir)
        Paging.current_page_dir = Pointer(PageStructs::PageDirectory).new(dir.to_u64)
        Paging.enable

        asm("jmp kcpuint_end" :: "{esp}"(pointerof(process_frame)) : "volatile")
    else
        frame.eax = SYSCALL_ERR
    end
end