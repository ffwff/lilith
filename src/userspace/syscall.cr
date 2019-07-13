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
    if addr < 0x8000_0000 || addr < end_addr
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
SYSCALL_ERR = 255u32

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
    when 0 # open
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
    when 1 # read
        frame.eax = SYSCALL_ERR
    when 2 # write
        fdi = frame.ebx.to_i32
        frame.eax = SYSCALL_ERR
        arg = try!(checked_pointer(frame.edx)).as(SyscallData::SyscallStringArgument*)
        str = Slice.new(try!(checked_pointer(arg.value.str)).as(UInt8*), arg.value.len)
        fd = try!(Multiprocessing.current_process.not_nil!.get_fd(fdi))
        frame.eax = fd.not_nil!.node.not_nil!.write(str)
    when 3 # getpid
        frame.eax = Multiprocessing.current_process.not_nil!.pid
    else
        frame.eax = SYSCALL_ERR
    end
end