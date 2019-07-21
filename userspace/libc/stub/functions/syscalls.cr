require "../syscall_defs.cr"

lib LibC

    alias String = UInt8*
    struct SyscallStringArgument
        str : String
        len : UInt32
    end
    fun sysenter(eax : UInt32, ebx : UInt32, edx : UInt32) : UInt32

end

# IO
fun open(device : LibC::String, flags : Int32) : Int32
    LibC.sysenter(SC_OPEN, device.address.to_u32, 0).to_i32
end

fun write(fd : Int32, str : LibC::String, len : Int32) : Int32
    buf = uninitialized LibC::SyscallStringArgument
    buf.str = str
    buf.len = len
    LibC.sysenter(SC_WRITE, fd, pointerof(buf).address.to_u32).to_i32
end

fun read(fd : Int32, str : LibC::String, len : Int32) : Int32
    buf = uninitialized LibC::SyscallStringArgument
    buf.str = str
    buf.len = len
    LibC.sysenter(SC_READ, fd, pointerof(buf).address.to_u32).to_i32
end

# process
fun _exit : Nil
    LibC.sysenter(SC_EXIT, 0, 0)
end

fun spawn(file : LibC::String) : Int32
    LibC.sysenter(SC_SPAWN, file.address.to_u32, 0).to_i32
end

fun getcwd(str : LibC::String, len : Int32) : Int32
    buf = uninitialized LibC::SyscallStringArgument
    buf.str = str
    buf.len = len
    LibC.sysenter(SC_GETCWD, pointerof(buf).address.to_u32, 0).to_i32
end