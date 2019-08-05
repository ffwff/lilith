#pragma once

#include <stddef.h>

char *strdup(const char *s);
char *strerror(int errnum);
size_t strlen(const char *s);
char *strstr(const char *haystack, const char *needle);

int strcmp(const char *s1, const char *s2);
int strncmp(const char *s1, const char *s2, size_t n);

char *strcpy(char *dest, const char *src);
char *strncpy(char *dest, const char *src, size_t n);

char *strtok(char *str, const char *delim);
char *strtok_r(char *str, const char *delim, char **saveptr);

char *strcat(char *dest, const char *src);
char *strncat(char *dest, const char *src, size_t n);

char *strchr(const char *s, int c);
char *strrchr(const char *s, int c);

void *memcpy(void *dest, const void *src, size_t n);
void *memmove(void *dest, const void *src, size_t n);
void *memset(void *s, int c, size_t n);
int memcmp(const void *s1, const void *s2, size_t n);
void *memchr(const void *s, int c, size_t n);