#include <stdarg.h>
#include <stddef.h>
#include <string.h>

void *stdin, *stdout, *stderr;

extern int nputs(const char *data, size_t length);
extern int putchar(int data);
extern int putint(int data);

int printf(const char* restrict format, ...) {
    va_list args;
    va_start(args, format);

    int written = 0;

    while (*format != 0) {
        if (*format == '%') {
            *format++;
            switch (*format) {
                case 'c': {
                    *format++;
                    written += putchar(va_arg(args, int));
                    break;
                }
                case 's': {
                    *format++;
                    const char *str = va_arg(args, const char*);
                    written += nputs(str, strlen(str));
                    break;
                }
                default: {
                    written += putchar('%');
                    break;
                }
            }
        }

        const char *format_start = format;
        int amount = 0;
        while(*format != 0) {
            if(*format == '%') {
                break;
            }
            amount++;
            format++;
        }
        written += nputs(format_start, amount);
    }

    va_end(args);
    return written;
}