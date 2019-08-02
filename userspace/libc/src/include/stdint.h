#pragma once

typedef char                int8_t;
typedef unsigned char      uint8_t;
typedef short               int16_t;
typedef unsigned short     uint16_t;
typedef int                 int32_t;
typedef unsigned int       uint32_t;
typedef long long           int64_t;
typedef unsigned long long uint64_t;

typedef uint32_t uintptr_t;
typedef int32_t intptr_t;
typedef int32_t ptrdiff_t;
#define SIZET_MAX   UINT32_MAX
#define SIZE_MAX    UINT32_MAX
#define INTPTR_MAX  UINT32_MAX

#define INT16_MAX   0x7FFF
#define INT16_MIN   INT16_MAX
#define UINT16_MAX  0xFFFF

#define INT32_MAX   0x7FFFFFFF
#define INT32_MIN   INT32_MAX
#define UINT32_MAX  0xFFFFFFFF

#define INT64_MAX   0x7FFFFFFFFFFFFFFF
#define INT64_MIN   INT64_MAX
#define UINT64_MAX  0xFFFFFFFFFFFFFFFF