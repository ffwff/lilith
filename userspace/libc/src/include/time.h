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

struct tm {
    int tm_sec;
    int tm_min;
    int tm_hour;
    int tm_mday;
    int tm_mon;
    int tm_year;
    int tm_wday;
    int tm_yday;
    int tm_isdst;
};
struct tm *gmtime(const time_t *timep);