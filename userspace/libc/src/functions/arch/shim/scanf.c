#include <stdarg.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

typedef int (*ngets_fn_t)(char *buffer, size_t length, void *userptr);
typedef void (*nungetc_fn_t)(char ch, void *userptr);

struct sscanf_slice {
    char *str;
    size_t remaining;
    // overflow character for parsing ints and the like
    char overflow_ch;
};

static int __sscanf_ngets(char *buffer, size_t length, void *userptr) {
    struct sscanf_slice *slice = (struct sscanf_slice *)userptr;
    if(slice->str == 0) {
        return length;
    } else if (slice->overflow_ch != 0) {
        char ch = slice->overflow_ch;
        slice->overflow_ch = 0;
        return ch;
    } else if (slice->remaining > 0) {
        size_t copy_sz = 0;
        if (length > slice->remaining) {
            copy_sz = slice->remaining;
        } else {
            copy_sz = length;
        }
        if (!copy_sz)
            return 0;
        strncpy(buffer, slice->str, copy_sz);
        slice->remaining -= copy_sz;
        slice->str += copy_sz;
        return copy_sz;
    } else {
        return 0;
    }
}

static void __scanf_ungetc(char ch, void *userptr) {
    struct sscanf_slice *slice = (struct sscanf_slice *)userptr;
    slice->overflow_ch = ch;
}

// expose
static int __sscanf(ngets_fn_t ngets_fn, nungetc_fn_t ungetc_fn, void *userptr,
                    const char *restrict format, va_list args) {
    int readden = 0; // 200 IQ word
    int retval;

    while (*format != 0) {
        if (*format == '%') {
            format++;
            switch (*format) {
                case 0:
                    return readden;
                case 'c': {
                    format++;
                    int *chptr = va_arg(args, int*);
                    char ch;
                    if (!(retval = ngets_fn(&ch, 1, userptr)))
                        return readden;
                    *chptr = (int)ch;
                    readden += retval;
                    break;
                }
                case 's': {
                    // TODO
                    abort();
                    break;
                }
                case 'd': {
                    char ch = 0;
                    int num = 0;
                    int sign = 1;
                    // negative or digit
                    if (!(retval = ngets_fn(&ch, 1, userptr)))
                        return readden;
                    if (ch == '-') {
                        sign = -1;
                    } else if (isdigit(ch)) {
                        num = (int)(ch - '0');
                    } else {
                        return readden;
                    }
                    // digits
                    while ((retval = ngets_fn(&ch, 1, userptr))) {
                        if (isdigit(ch)) {
                            int digit = ch - '0';
                            num = num * 10 + digit;
                        } else {
                            break;
                        }
                    }
                    // return the last character to the buffer
                    ungetc_fn(ch, userptr);
                    // negate if necessary
                    num *= sign;
                    // store
                    int *intptr = va_arg(args, int *);
                    *intptr = num;
                    break;
                }
                default: {
                    format--;
                    break;
                }
            }
        }

        const char *format_start = format;
        int amount = 0;
        while (*format != 0) {
            if (*format == '%') {
                break;
            }
            amount++;
            format++;
        }
        char target[amount];
        if (!(retval = ngets_fn(target, amount, userptr)))
            return readden;
        if (retval != amount || strncmp(target, format_start, amount) != 0)
            return readden;
        readden += retval;
    }

    return readden;
}

int sscanf(char *str, const char *format, ...) {
    va_list args;
    va_start(args, format);
    struct sscanf_slice slice = {
        .str = str,
        .remaining = INT_MAX,
        .overflow_ch = 0,
    };
    int ret = __sscanf(__sscanf_ngets, __scanf_ungetc, &slice, format, args);
    va_end(args);

    return ret;
}