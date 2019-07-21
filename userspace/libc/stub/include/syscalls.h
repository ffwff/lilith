#ifndef _LIBC_SYSCALLS
#define _LIBC_SYSCALLS

int open(const char *device, int flags);
long write(int fd, const void *str, size_t len);
long read(int fd, char *str, unsigned long len);
// process
typedef long pid_t;
pid_t spawn(const char *file);
pid_t getpid();
int getcwd(char *buf, unsigned long length);
int chdir(char *buf);

// defines
#define PATH_MAX 4096

#endif