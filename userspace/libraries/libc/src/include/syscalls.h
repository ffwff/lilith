#pragma once

#include <stddef.h>

typedef unsigned long mode_t;
typedef unsigned long off_t;

int open(char *device, int flags, ...);
int create(char *device);
int close(int fd);
long write(int fd, void *str, size_t len);
long read(int fd, char *str, size_t len);
int ftruncate(int fd, off_t length);
int _ioctl(int fd, int request, unsigned int arg);
int waitfd(int *fds, size_t nfds, useconds_t timeout);
int remove(char *device);

time_t _sys_time();

typedef long pid_t;
void _exit();

struct startup_info {
	int stdin;
	int stdout;
	int stderr;
};
pid_t spawnv(char *file, char **argv);
pid_t spawnxv(struct startup_info *startup_info, char *file, char **argv);

int usleep(useconds_t usec);
#define sleep(x) usleep((x)*1000000)

pid_t waitpid(pid_t pid, int *status, int options);
pid_t getpid();

int getcwd(char *buf, unsigned long length);
int chdir(char *buf);

off_t lseek(int fd, off_t offset, int whence);

#define PATH_MAX 4096
#define FILENAME_MAX 256

#define ENOENT   0

#define O_RDONLY (1 << 0)
#define O_WRONLY (1 << 1)
#define O_RDWR   (O_RDONLY | O_WRONLY)
#define O_CREAT  (1 << 2)
#define O_TRUNC  (1 << 3)
#define O_APPEND (1 << 4)
