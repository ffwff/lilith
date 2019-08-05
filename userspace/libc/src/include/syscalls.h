#pragma once

#include <stddef.h>

typedef unsigned long mode_t;
typedef unsigned long off_t;

int _open(char *device, int flags, mode_t mode);
#define open(device, flags) _open(device, flags, 0)
#define open(device, flags, mode) _open(device, flags, mode)
int close(int fd);
long write(int fd, void *str, size_t len);
long read(int fd, char *str, unsigned long len);
int ftruncate(int fildes, off_t length);

typedef long pid_t;
pid_t spawnv(char *file, char **argv);
pid_t waitpid(pid_t pid, int *status, int options);
pid_t getpid();
int getcwd(char *buf, unsigned long length);
int chdir(char *buf);

int atexit(void (*function)(void));

#define PATH_MAX 4096

#define ENOENT   0

#define O_RDONLY (1 << 0)
#define O_WRONLY (1 << 1)
#define O_RDWR   (O_RDONLY | O_WRONLY)

#define O_CREAT  (1 << 2)