#pragma once

#include <syscalls.h>
#include <termios.h>

#define ENOTTY 0
#define ENOENT 0

int isatty(int fd);