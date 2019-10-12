#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syscalls.h>

static void spawn_process(char *s, char **argv, int wait_proc) {
  if (!argv[0]) {
    return;
  } else if (!argv[0][0]) {
    return;
  }

  pid_t child = spawnv(s, argv);
  if (child > 0) {
    if(wait_proc)
      waitpid(child, 0, 0);
    else
      printf("[%d]\n", child);
  } else
    printf("unknown command or file name\n");
}

static void interpret_line(char *buf) {
  char *tok = strtok(buf, " ");
  if (tok != NULL) {
    if(strcmp(tok, "cd") == NULL) {
      char *tok = strtok(NULL, "\n");
      chdir(tok);
    } else {
      const int MAX_ARGS = 256;
      char **argv = malloc(MAX_ARGS * sizeof(char *));
      argv[0] = tok;
      int idx = 1;
      while((tok = strtok(NULL, " ")) != NULL && idx < (MAX_ARGS - 1)) {
        if(tok[0] != 0) {
          argv[idx] = tok;
          idx++;
        }
      }
      argv[idx] = NULL;
      if(strcmp(argv[idx - 1], "&") == 0) {
        argv[idx - 1] = NULL;
        spawn_process(buf, argv, 0);
      } else {
        spawn_process(buf, argv, 1);
      }
      free(argv);
    }
    fflush(stdout);
  }
}

int main(int argc, char **argv) {
  if (read(STDIN_FILENO, NULL, 0) < 0)
    open("/kbd", O_RDONLY);
  if (write(STDOUT_FILENO, NULL, 0) < 0)
    open("/con", O_WRONLY);
  //if (write(STDERR_FILENO, NULL, 0) < 0)
  //  open("/serial", O_WRONLY);

  if(argc == 2) {
    FILE *f = fopen(argv[1], "r");
    if(!f) return 1;
    
    char *line = 0;
    size_t len = 0;
    ssize_t nread = 0;
    while ((nread = getline(&line, &len, f)) != EOF) {
      interpret_line(line);
    }
    
    free(line);
    return 0;
  }

  // shell
  char *path = calloc(PATH_MAX + 1, 1);
  while(1) {
    getcwd(path, PATH_MAX);

    printf("%s> ", path);
    fflush(stdout);

    char buf[256]={0};
    if(!fgets(buf, sizeof(buf), stdin))
      return 0;
    if(buf[0] == 0)
      continue;
    buf[strlen(buf) - 1] = 0; // trim '\n'

    interpret_line(buf);
  }
}
