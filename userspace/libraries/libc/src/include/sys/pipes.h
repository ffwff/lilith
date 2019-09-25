#pragma once

#include <syscalls.h>

int mkpipe(const char *path);
int mkfpipe(const char *path, unsigned int flags);
int mkppipe(const char *path, unsigned int flags, pid_t pid);

#define PIPE_CONF_FLAGS  6
#define PIPE_CONF_PID    7
#define PIPE_WAIT_READ  (1 << 0)

#define PIPE_M_RD  (1 << 1)
#define PIPE_S_RD  (1 << 2)
#define PIPE_M_WR  (1 << 3)
#define PIPE_S_WR  (1 << 4)
#define PIPE_G_RD  (1 << 5)
#define PIPE_G_WR  (1 << 6)
