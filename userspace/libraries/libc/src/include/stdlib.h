#pragma once

#include <stddef.h>

void *malloc(size_t size);
void free(void *ptr);
void *calloc(size_t nmemb, size_t size);
void *realloc(void *ptr, size_t size);

unsigned long int strtoul(const char *nptr, char **endptr, int base);
long int strtol(const char *nptr, char **endptr, int base);
double strtod(const char *nptr, char **endptr);

int abs(int j);
long int labs(long int j);
long long int llabs(long long int j);

void exit(int status);
void abort(void);

char *getenv(const char *name);
int setenv(const char *name, const char *value, int overwrite);

#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1

#define offsetof(st, m) __builtin_offsetof(st, m)

int rand(void);
void qsort(void *base, size_t nmemb, size_t size,
           int (*compar)(const void *, const void *));

int atoi(const char *nptr);
long atol(const char *nptr);
double atof(const char *nptr);