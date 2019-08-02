#include <stdarg.h>
#include <stddef.h>

void *stdin, *stdout, *stderr;

extern int puts(const char* data);
extern int nputs(const char* data, size_t length);
extern int putchar(int data);

int printf(const char* restrict format, ...) {
    va_list parameters;
    va_start(parameters, format);

    int written = 0;

    while (*format != '\0') {
        size_t maxrem = INT_MAX - written;

        if (format[0] != '%' || format[1] == '%') {
            if (format[0] == '%')
                format++;
            size_t amount = 1;
            while (format[amount] && format[amount] != '%')
                amount++;
            if (maxrem < amount) {
                // TODO: Set errno to EOVERFLOW.
                return -1;
            }
            if (!nputs(format, amount))
                return -1;
            format += amount;
            written += amount;
            continue;
        }

        const char* format_begun_at = format++;

        switch(*format) {
            case 'c': {
                format++;
                int c = va_arg(parameters, int);
                if (!maxrem) {
                    // TODO: Set errno to EOVERFLOW.
                    return -1;
                }
                if (!putchar(c))
                    return -1;
                written++;
                break;
            }
            case 's': {
                format++;
                const char* str = va_arg(parameters, const char*);
                size_t len;
                if (!(len = puts(str)))
                    return -1;
                if (maxrem < len)
                    return -1;
                written += len;
                break;
            }
            default: {
                format = format_begun_at;
                size_t len;
                if (!(len = puts(format)))
                    return -1;
                if (maxrem < len)
                    return -1;
                written += len;
                format += len;
                break;
            }
        }
    }

    va_end(parameters);
    return written;
}