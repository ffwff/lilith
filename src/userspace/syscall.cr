require "../drivers/cpumsr.cr"

lib SyscallData

    @[Packed]
    struct Registers
        # Pushed by pushad:
        # ecx is unused
        edi, esi, ebp, esp, ebx, edx, ecx_, eax : UInt32
    end

end

def checked_pointer(addr : UInt32) : Void* | Nil
    if addr < 0x8000_0000
        nil
    else
        Pointer(Void).new(addr.to_u64)
    end
end

SYSCALL_ERR = 255u32

fun ksyscall_handler(frame : SyscallData::Registers)
    case frame.eax
    when 0 # open
        path = NullTerminatedSlice.new(checked_pointer(frame.ebx).not_nil!.as(UInt8*))
        vfs_node : VFSNode | Nil = nil
        i = 0
        pslice_start = 0
        while i < path.size
            #Serial.puts path[i].unsafe_chr
            if path[i] == '/'.ord
                # ignore multi occurences of slashes
                if pslice_start - i != 0
                    # search for root subsystems
                    subpath = path[pslice_start..i]
                    Serial.puts '\n'
                end
                pslice_start = i
            else
            end
            i += 1
        end
        if vfs_node.nil? # no path specifier
            rpath = path[pslice_start..i]
            ROOTFS.each do |fs|
                if rpath == fs.name
                    node = fs.open("")
                    if node.nil?
                        frame.eax = SYSCALL_ERR
                    else
                        frame.eax = Multiprocessing.current_process.not_nil!.install_fd(node.not_nil!)
                        # panic "opened! ", frame.eax, '\n'
                    end
                    return
                end
            end
        end
        frame.eax = SYSCALL_ERR
    when 1 # read
        frame.eax = SYSCALL_ERR
    when 2 # write
        fdi = frame.ebx.to_i32
        str = NullTerminatedSlice.new(checked_pointer(frame.edx).not_nil!.as(UInt8*))
        if (fd = Multiprocessing.current_process.not_nil!.get_fd(fdi)).nil?
            frame.eax = SYSCALL_ERR
        else
            frame.eax = fd.not_nil!.node.not_nil!.write(str)
        end
    when 3 # getpid
        frame.eax = Multiprocessing.current_process.not_nil!.pid
    else
        frame.eax = SYSCALL_ERR
    end
end