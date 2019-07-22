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
        int j = 0;
        for(int i = 0; i < sizeof(buf)-1; i++, j++) {
            char ch = fgetc(stdin);
            if(ch == '\n') break;
            buf[i] = ch;
        }
        buf[j] = 0;

        char *tok_s = strdup(buf);
        char *tok = strtok(tok_s, " ");
        if(strcmp(tok, "cd") == NULL) {
            chdir(strtok(NULL, ""));
        } else {
            spawn(buf);
        }
        free(tok_s);
        fflush(stdout);
    }
}