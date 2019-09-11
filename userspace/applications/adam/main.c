#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syscalls.h>

void spawn_process(char *s, char **argv) {
    if (!argv[0]) {
        return;
    } else if (!argv[0][0]) {
        return;
    }

    pid_t child = spawnv(s, argv);
    if (child > 0)
        waitpid(child, 0, 0);
    else
        printf("unknown command or file name\n");
}

int main(int argc, char **argv) {
    // FIXME: check stdin, stdout and launch tty correctly
    close(STDIN_FILENO);
    open("/kbd", O_RDONLY);
    open("/con", O_WRONLY);
    open("/con", O_WRONLY);

    // shell
    char *path = calloc(PATH_MAX + 1, 1);
    while(1) {
        getcwd(path, PATH_MAX);

        printf("%s> ", path);
        fflush(stdout);

        char buf[256]={0};
        fgets(buf, sizeof(buf), stdin);
        buf[strlen(buf) - 1] = 0; // trim '\n'

        char *tok = strtok(buf, " ");
        if (tok != NULL) {
            if(strcmp(tok, "cd") == NULL) {
                chdir(strtok(NULL, ""));
            } else {
                const int MAX_ARGS = 256;
                char **argv = malloc(MAX_ARGS * sizeof(char *));
                argv[0] = tok;
                int idx = 1;
                while((tok = strtok(NULL, " ")) != NULL && idx < (MAX_ARGS - 1)) {
                    argv[idx] = tok;
                    idx++;
                }
                argv[idx] = NULL;
                spawn_process(buf, argv);
                free(argv);
            }
            fflush(stdout);
        }
    }
}