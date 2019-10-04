#include <stddef.h>
#include <stdio.h>
#include <time.h>

struct timeval __libc_timeval;
struct tm __libc_tm;

size_t strftime(char *s, size_t max, const char *format,
                       const struct tm *tm) {
  size_t i = 0, j = 0;
  while(format[i]) {
    if(format[i] == '%') {
      i++;
      switch(format[i]) {
      #define FORMAT(ch, fmt, num)                   \
        case ch: {                                   \
          i++;                                       \
          size_t remaining = max - j;                \
          j += snprintf(s + j, remaining, fmt, num); \
          if(j == max)                               \
            return j;                                \
          break;                                     \
        }
        FORMAT('Y', "%d", tm->tm_year)
        FORMAT('m', "%d", tm->tm_mon)
        FORMAT('d', "%d", tm->tm_mday)
        FORMAT('H', "%02d", tm->tm_hour)
        FORMAT('M', "%02d", tm->tm_min)
        FORMAT('S', "%02d", tm->tm_sec)
        case '%': {
          i++;
          if(j == max)
            return j;
          s[j++] = '%';
          break;
        }
        default: {
          i++;
          return j;
        }
      }
    } else {
      if(j == max)
        return j;
      s[j++] = format[i++];
    }
  }
  
  s[j] = 0;
  return j;
}
