#pragma once

#define NULL 0
#define INT_MAX 0xFFFFFFFF

typedef unsigned long size_t;
typedef long ssize_t;

typedef unsigned long uintptr_t;
typedef long intptr_t;
typedef long ptrdiff_t;

typedef unsigned char wchar_t;

#if defined(__GNUC__) || defined(__clang__)
#define offsetof(st, m) __builtin_offsetof(st, m)
#else
#define offsetof(s,memb) \
    ((size_t)((char *)&((s *)0)->memb - (char *)0))
#endif

typedef unsigned long long time_t;
typedef unsigned long long suseconds_t;
typedef long long useconds_t;
typedef unsigned long long clock_t;
