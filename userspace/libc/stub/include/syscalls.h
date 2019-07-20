static unsigned long sysenter(unsigned long eax, unsigned long ebx, unsigned long edx) {
    unsigned long ret;
    __asm__ volatile(
        "push $1f\n"
        "mov %%esp, %%ecx\n"
        "sysenter\n"
        "1: add $4, %%esp\n"
        : "=a"(ret)
        : "a"(eax), "b"(ebx), "d"(edx)
        : "cc", "ecx", "edi", "esi", "memory");
    return ret;
}

// io
int open(const char *device, int flags);
long write(int fd, const void *str, size_t len);
long read(int fd, char *str, unsigned long len);
// process
typedef long pid_t;
pid_t spawn(const char *file);
pid_t getpid();
long getcwd(char *buf, unsigned long length);

// defines
#define PATH_MAX 4096