lib LibC

    struct Dirent
        # Inode number
        d_ino : Ino_t
        # Length of this record 
        d_reclen : UInt16
        # Type of file; not supported by all filesystem types
        d_type : UInt8
        # Null-terminated filename
        d_name : UInt8[256]
    end

end

fun opendir(dirname : LibC::String)
end

fun closedir(dirname : LibC::String)
end