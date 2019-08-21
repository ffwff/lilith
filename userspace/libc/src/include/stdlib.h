#pragma once

#include <stddef.h>

void *malloc(size_t size);
void free(void *ptr);
void *calloc(size_t nmemb, size_t size);
void *realloc(void *ptr, size_t size);

unsigned long int strtoul(const char *nptr, char **endptr, int base);

void exit(int status);
void abort(void);

char *getenv(const char *name);
int setenv(const char *name, const char *value, int overwrite);

#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1