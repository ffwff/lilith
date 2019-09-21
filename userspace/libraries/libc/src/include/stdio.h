#pragma once

#include <stddef.h>
#include <stdarg.h>

typedef void FILE;
typedef void *fpos_t;

extern FILE *stdin;
extern FILE *stdout;
extern FILE *stderr;

FILE *fopen(const char *pathname, const char *mode);
FILE *freopen(const char *pathname, const char *mode, FILE *stream);
FILE *tmpfile(void);
int fclose(FILE *stream);

int fflush(FILE *);

char *fgets(char *, int, FILE *);
int fgetc(FILE *stream);
#define getc(x) fgetc(x)
int fputs(const char *s, FILE *stream);
int fnputs(const char *s, unsigned long len, FILE *stream);

size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
size_t fwrite(const void *ptr, size_t size, size_t nmemb,
              FILE *stream);

int fseek(FILE *stream, long offset, int whence);
long ftell(FILE *stream);
int fgetpos(FILE *stream, fpos_t *pos);
int fsetpos(FILE *stream, const fpos_t *pos);
void rewind(FILE *stream);

int feof(FILE *stream);
int ferror(FILE *stream);
int fileno(FILE *stream);

int printf(const char *format, ...);
int fprintf(FILE *stream, const char *format, ...);
int dprintf(int fd, const char *format, ...);
int sprintf(char *str, const char *format, ...);
int snprintf(char *str, size_t size, const char *format, ...);

int vfprintf(FILE *stream, const char *format, va_list ap);
int vsnprintf(char *str, size_t size, const char *format, va_list ap);

int sscanf(const char *str, const char *format, ...);

int fputc(int c, FILE *stream);
int fputs(const char *s, FILE *stream);
int putc(int c, FILE *stream);
int puts(const char *s);
int getchar(void);

void perror(const char *s);

ssize_t getline(char **lineptr, size_t *n, FILE *stream);

int setvbuf(FILE *stream, char *buf, int mode, size_t size);

char * tmpnam (char * str);
#define L_tmpnam 32

#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

#define EOF (char)-4

#define BUFSIZ 256

#define _IONBF 0
#define _IOLBF 1
#define _IOFBF 2
