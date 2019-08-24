#pragma once
#include <stdint.h>

typedef uint32_t time_t;
time_t time(time_t *tloc);

typedef uint32_t suseconds_t;

struct timeval {
    time_t tv_sec;
    suseconds_t tv_usec;
};
int gettimeofday(struct timeval *restrict tp, void *restrict tzp);