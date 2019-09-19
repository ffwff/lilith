#include <stdio.h>
#include <time.h>
#include <syscalls.h>

int main(int argc, char **argv) {
  char *format = "%d/%m/%Y %H:%M:%S";
  struct tm *timeinfo;
  time_t now = _sys_time();
  timeinfo = localtime(&now);
  
  char buf[128] = {0};
  strftime(buf, sizeof(buf), format, timeinfo);
  puts(buf); 
  
  return 0;
}
