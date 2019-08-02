#include <stdarg.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>

void *stdin, *stdout, *stderr;

extern int nputs(const char *data, size_t length);
typedef int (*nputs_fn_t)(const char *data, size_t length, void *userptr);

static int __printf(nputs_fn_t nputs_fn, void *userptr,
                    const char *restrict format, va_list args) {
    int written = 0;
    int retval;

    while (*format != 0) {
        if (*format == '%') {
            format++;
            switch (*format) {
                case 0:
                    return written;
                case 'c': {
                    format++;
                    char ch = (char)va_arg(args, int);
                    if (!(retval = nputs_fn(&ch, 1, userptr)))
                        return written;
                    written += retval;
                    break;
                }
                case 's': {
                    format++;
                    const char *str = va_arg(args, const char *);
                    if (!(retval = nputs_fn(str, strlen(str), userptr)))
                        return written;
                    written += retval;
                    break;
                }
                default: {
                    if (!(retval = nputs_fn(format - 1, 1, userptr)))
                        return written;
                    written += retval;
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
        if (!(retval = nputs_fn(format_start, amount, userptr)))
            return written;
        written += retval;
    }

    return written;
}

// regular printf
static int printf_nputs(const char *data, size_t length, void *userptr) {
    return nputs(data, length);
}

int printf(const char *restrict format, ...) {
    va_list args;
    va_start(args, format);
    int ret = __printf(printf_nputs, 0, format, args);
    va_end(args);

    return ret;
}

// fprintf
static int fprintf_nputs(const char *data, size_t length, void *userptr) {
    return fnputs(data, length, (FILE*)userptr);
}

int fprintf(FILE *stream, const char *restrict format, ...) {
    va_list args;
    va_start(args, format);
    int ret = __printf(fprintf_nputs, stream, format, args);
    va_end(args);

    return ret;
}

// string
struct sprintf_slice {
    char *str;
    size_t remaining;
};

static int sprintf_nputs(const char *data, size_t length, void *userptr) {
    struct sprintf_slice *slice = (struct sprintf_slice *)userptr;
    if(slice->str == 0) {
        return length;
    } else if(slice->remaining > 0) {
        size_t copy_sz = 0;
        if (length > slice->remaining) {
            copy_sz = slice->remaining;
        } else {
            copy_sz = length;
        }
        strncpy(slice->str, data, copy_sz);
        slice->str[copy_sz] = 0;
        slice->remaining -= copy_sz;
        slice->str += copy_sz; // skip nul
        return copy_sz;
    } else {
        return 0;
    }
}

int sprintf(char *str, const char *restrict format, ...) {
    va_list args;
    va_start(args, format);
    struct sprintf_slice slice = {
        .str = str,
        .remaining = INT_MAX,
    };
    int ret = __printf(sprintf_nputs, &slice, format, args);
    va_end(args);

    return ret;
}

int snprintf(char *str, size_t size, const char *restrict format, ...) {
    va_list args;
    va_start(args, format);
    struct sprintf_slice slice = {
        .str = str,
        .remaining = size,
    };
    int ret = __printf(sprintf_nputs, &slice, format, args);
    va_end(args);

    return ret;
}