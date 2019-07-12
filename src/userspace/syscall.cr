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

fun ksyscall_handler(frame : SyscallData::Registers)
    case frame.eax
    when 0 # open
        path = NullTerminatedSlice.new(checked_pointer(frame.ebx).not_nil!.as(UInt8*))
        i = 0
        pslice_start = 0
        while i < path.size
            if path[i] == '/'.ord
                # ignore multi occurences of slashes
                if pslice_start - i != 0
                    # search for root subsystems
                end
                pslice_start = i
            else
            end
            i += 1
        end
    when 1 # read
        # ...
    when 2 # write
        # ...
    when 3 # getpid
        frame.eax = Multiprocessing.current_process.not_nil!.pid
    else
        frame.eax = 1
    end
end