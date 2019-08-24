#pragma once

extern void __assert__(int truthy, const char *s);
#define assert(x) __assert__((int)(x), #x)