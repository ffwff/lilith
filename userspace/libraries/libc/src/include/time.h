#pragma once

#include <stddef.h>

time_t time(time_t *tloc);

struct timeval {
    time_t tv_sec;
    suseconds_t tv_usec;
};
int gettimeofday(struct timeval *tp, void *tzp);

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
struct tm *localtime(const time_t *timep);

time_t mktime(struct tm *tm);
size_t strftime(char *s, size_t max, const char *format,
                       const struct tm *tm);

#define CLOCKS_PER_SEC 1000000
