#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syscalls.h>

int main() {
    char *path = calloc(PATH_MAX + 1, 1);
    while(1) {
        getcwd(path, PATH_MAX);

        printf("%s> ", path);
        fflush(stdout);

        char buf[256]={0};
        int i = 0;
        for(; i < sizeof(buf)-1; i++) {
            char ch = fgetc(stdin);
            if(ch == '\n')
                break;
            else if(ch == '\b' && i > 0)
                i--;
            else
                buf[i] = ch;
        }
        buf[i] = 0;

        char *tok_s = strdup(buf);
        char *tok = strtok(tok_s, " ");
        if (tok != NULL) {
            if(strcmp(tok, "cd") == NULL) {
                chdir(strtok(NULL, ""));
            } else {
                spawn(buf);
            }
            fflush(stdout);
        }
        free(tok_s);
    }
}