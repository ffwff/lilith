require "../drivers/cpumsr.cr"

lib SyscallData

    @[Packed]
    struct Registers
        # Pushed by pushad:
        # ecx is unused
        edi, esi, ebp, esp, ebx, edx, retval, eax : UInt32
    end

end

fun ksyscall_handler(frame : SyscallData::Registers)
    Serial.puts frame.eax, "\n"
    Serial.puts frame.ebx, "\n"
    if frame.eax == 0
        # write
        ptr = Pointer(UInt8).new(frame.ebx.to_u64)
        Serial.puts "ebx ptr:", ptr, '\n'
        i = 0
        while ptr[i] != 0
            VGA.puts ptr[i].unsafe_chr
            i += 1
        end
        VGA.puts "\n"
    end
end