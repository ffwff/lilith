#include <syscalls.h>
#include <stdarg.h>

int _open(char *device, int flags);

int open(char *device, int flags, ...) {
  va_list vl;
  va_start(vl, flags);
  if((flags & O_CREAT) != 0) {
    int mode = va_arg(vl, int);
    va_end(vl);
    (void)mode; // TODO: set mode
    int fd = create(device, flags);
    return fd;
  }
  va_end(vl);
  return _open(device, flags);
}
