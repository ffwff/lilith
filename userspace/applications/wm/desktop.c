#include <syscalls.h>

static char *startup[] = {
  "pape", "pape", "/hd0/share/papes/violet.png", NULL,
  "cbar", "cbar", NULL,
  "cterm", "cterm", NULL,
  NULL,
};

int main(int argc, char **argv) {
  int startup_items = sizeof(startup)/sizeof(startup[0]);
  for(int i = 0; i < startup_items;) {
    char *binary = startup[i++];
    char **argv = &startup[i];
    while(startup[i]) { // skip to null
      i++;
    }
    i++; // skip to next entry
    spawnv(binary, argv);
  }
}
