#pragma once

#include <stddef.h>

typedef void FILE;

extern FILE *stdin;
extern FILE *stdout;
extern FILE *stderr;

int fflush(FILE *);
char *fgets(char *, int, FILE *);

int printf(const char *format, ...);
int fprintf(FILE *stream, const char *format, ...);
int dprintf(int fd, const char *format, ...);
int sprintf(char *str, const char *format, ...);
int snprintf(char *str, size_t size, const char *format, ...);
