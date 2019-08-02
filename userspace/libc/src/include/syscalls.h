#ifndef _LIBC_SYSCALLS
#define _LIBC_SYSCALLS

#include <stddef.h>

int open(char *device, int flags);
long write(int fd, void *str, size_t len);
long read(int fd, char *str, unsigned long len);
// process
typedef long pid_t;
pid_t spawnv(char *file, char **argv);
pid_t waitpid(pid_t pid, int *status, int options);
pid_t getpid();
int getcwd(char *buf, unsigned long length);
int chdir(char *buf);

// defines
#define PATH_MAX 4096

#endif