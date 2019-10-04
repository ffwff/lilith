#include <stdarg.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

void *stdin, *stdout, *stderr;

static const char null_str[] = "(null)";
static const size_t null_str_length = sizeof(null_str);

extern int nputs(const char *data, size_t length);
typedef int (*nputs_fn_t)(const char *data, size_t length, void *userptr);

#define ITOA_BUFFER_LEN 128

static const char __printf_itoa_buf[] = "0123456789abcdefghijklmnopqrstuvwxyz";

static void __printf_reverse(char *str, int length) {
  for (int i = 0, j = length - 1; i < j; i++, j--) {
    char c = str[i];
    str[i] = str[j];
    str[j] = c;
  }
}

#define PRINTF_GENERIC_INT(fn_name, type)           \
static inline int                                   \
fn_name(type num, int base, char *str) {            \
  int sign = num < 0;                               \
  if(num < 0)                                       \
    num *= -1;                                      \
  int i = 0;                                        \
  for(; i < ITOA_BUFFER_LEN - 2; i++) {             \
    str[i] = __printf_itoa_buf[num % base];         \
    num /= base;                                    \
    if(!num) break;                                 \
  }                                                 \
  i++;                                              \
  if(sign) {                                        \
    str[i++] = '-';                                 \
  }                                                 \
  __printf_reverse(str, i);                         \
  str[i] = 0;                                       \
  return i;                                         \
}

PRINTF_GENERIC_INT(__printf_itoa, int)
PRINTF_GENERIC_INT(__printf_uitoa, unsigned int)
PRINTF_GENERIC_INT(__printf_ltoa, long)
PRINTF_GENERIC_INT(__printf_lltoa, long long)

static int __printf(nputs_fn_t nputs_fn, void *userptr,
          const char *restrict format, va_list args) {
  int written = 0;
  int retval;

  while (*format != 0) {
    if (*format == '%') {
      char __itoa_buf[ITOA_BUFFER_LEN];
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
          if(str == 0) {
            if (!(retval = nputs_fn(null_str, null_str_length, userptr))) {
              return written;
            }
          } else if (!(retval = nputs_fn(str, strlen(str), userptr)))
            return written;
          written += retval;
          break;
        }
#define HANDLE_XINT_FORMAT(type, formatc, base, fn)         \
  case formatc: {                                           \
    format++;                                               \
    type num = va_arg(args, type);                          \
    int length = fn(num, base, __itoa_buf);                 \
    if (!(retval = nputs_fn(__itoa_buf, length, userptr)))  \
      return written;                                       \
    written += retval;                                      \
    break;                                                  \
  }
#define HANDLE_INT_FORMAT(formatc, base) HANDLE_XINT_FORMAT(int, formatc, base, __printf_itoa)
        HANDLE_INT_FORMAT('d', 10)
        HANDLE_INT_FORMAT('x', 16)
        HANDLE_INT_FORMAT('o', 8)
        case 'f': {
          // FIXME: naive implementation, please replace me
          format++;
          int length;

          double fp = va_arg(args, double);
          int integer_part = (int)fp;

          unsigned long decimal_part;
          if (fp >= 0) {
            decimal_part = (unsigned long) \
              ((fp - (double)integer_part) * 1000000000.0);
          } else {
            decimal_part = (unsigned long) \
              (((double)integer_part - fp) * 1000000000.0);
          }
          
          length = __printf_itoa(integer_part, 10, __itoa_buf);
          if (!(retval = nputs_fn(__itoa_buf, length, userptr)))
            return written;
          written += retval;

          char ch = '.';
          if (!(retval = nputs_fn(&ch, 1, userptr)))
            return written;
          written += retval;

          length = __printf_uitoa(decimal_part, 10, __itoa_buf);
          if (!(retval = nputs_fn(__itoa_buf, length, userptr)))
            return written;
          written += retval;

          break;
        }
        case 'l': {
          format++;
          switch (*format) {
            case 0:
              return written;
            case 'l': {
              format++;
              switch (*format) {
                case 0:
                default: {
                  return written;
                }
                HANDLE_XINT_FORMAT(long long, 'd', 10, __printf_lltoa)
                HANDLE_XINT_FORMAT(long long, 'x', 16, __printf_lltoa)
                HANDLE_XINT_FORMAT(long long, 'o', 8, __printf_lltoa)
              }
              break;
            }
            HANDLE_XINT_FORMAT(long, 'd', 10, __printf_ltoa)
            HANDLE_XINT_FORMAT(long, 'x', 16, __printf_ltoa)
            HANDLE_XINT_FORMAT(long, 'o', 8, __printf_ltoa)
            default: {
              fputs("unsupported long format: ", stderr);
              fputc(*format, stderr);
              fputc('\n', stderr);
              return written;
            }
          }
          break;
        }
        case 'p': {
          format++;

          const char *ptr_begin = "0x";
          if (!(retval = nputs_fn(ptr_begin, strlen(ptr_begin), userptr)))
            return written;
          written += retval;

          unsigned long num = (unsigned long)va_arg(args, void*);
          int length = __printf_uitoa(num, 16, __itoa_buf);
          if (!(retval = nputs_fn(__itoa_buf, length, userptr)))
            return written;
          written += retval;

          break;
        }
        case '0': {
          format++;
          int ndigits = 0;
          while(isdigit(*format)) {
            int digit = *format - '0';
            ndigits = ndigits * 10 + digit;
            format++;
          }
          switch(*format) {
          #define HANDLE_PAD_INT_FORMAT(formatc, base)           \
            case formatc: {                                      \
              format++;                                          \
              int num = va_arg(args, int);                       \
              int length = __printf_itoa(num, base, __itoa_buf); \
              if(length < ndigits) {                             \
                char pad = '0';                                  \
                for(int i = length; i < ndigits; i++) {          \
                  if (!(retval = nputs_fn(&pad, 1, userptr)))    \
                    return written;                              \
                  written++;                                     \
                }                                                \
              }                                                  \
              if (!(retval = nputs_fn(__itoa_buf, length, userptr))) \
                return written;                                  \
              written += length;                                 \
              break;                                             \
            }
            HANDLE_PAD_INT_FORMAT('d', 10)
            HANDLE_PAD_INT_FORMAT('x', 16)
            HANDLE_PAD_INT_FORMAT('o', 8)
            default: {
              return written;
            }
          }
        }
        default: {
          fputs("unsupported format: ", stderr);
          fputc(*format, stderr);
          fputc('\n', stderr);
          return written;
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
    if (amount) {
      if (!(retval = nputs_fn(format_start, amount, userptr)))
        return written;
      written += retval;
    }
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

int vfprintf(FILE *stream, const char *format, va_list ap) {
  return __printf(fprintf_nputs, stream, format, ap);
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
    if (!copy_sz)
      return 0;
    strncpy(slice->str, data, copy_sz);
    slice->str[copy_sz] = 0;
    slice->remaining -= copy_sz;
    slice->str += copy_sz;
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
  if(size < 1)
    return 0;

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

int vsnprintf(char *str, size_t size, const char *restrict format, va_list args) {
  if(size < 1)
    return 0;

  struct sprintf_slice slice = {
    .str = str,
    .remaining = size,
  };
  int ret = __printf(sprintf_nputs, &slice, format, args);
  return ret;
}
