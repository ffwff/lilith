SYSCALL_ERR = (-1).to_u32
SYSCALL_SUCCESS = 1u32

SC_OPEN   = 0u32
SC_READ   = 1u32
SC_WRITE  = 2u32
SC_GETPID = 3u32
SC_SPAWN  = 4u32
SC_CLOSE  = 5u32
SC_EXIT   = 6u32
SC_SEEK   = 7u32
SC_GETCWD = 8u32
SC_CHDIR  = 9u32
SC_SBRK   = 10u32

SC_SEEK_SET = 0u32
SC_SEEK_CUR = 1u32
SC_SEEK_END = 2u32