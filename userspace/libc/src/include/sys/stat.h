#pragma once

#include <syscalls.h>
#include <time.h>

#define R_OK 0
#define W_OK 0

struct stat {
    mode_t st_mode;
    time_t st_atime;
    time_t st_mtime;
    time_t st_ctime;
};

#define S_ISDIR(x) 0