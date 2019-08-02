#pragma once

typedef void (*sighandler_t)(int);
sighandler_t signal(int signum, sighandler_t handler);

typedef unsigned long sig_atomic_t;

#define SIGABRT 0
#define SIGFPE  1
#define SIGILL  2
#define SIGINT  3
#define SIGSEGV 4
#define SIGTERM 5

#define SIG_DFL 0
#define SIG_IGN 0xFFFFFFFF