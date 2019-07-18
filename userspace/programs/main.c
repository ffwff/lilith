#include <stdio.h>
#include <syscalls.h>

int main() {
    while(1) {
        char buf[256]={0};
        printf("> ");
        fflush(stdout);

        for(int i = 0; i < sizeof(buf)-1; i++) {
            char ch = fgetc(stdin);
            if(ch == '\n') break;
            buf[i] = ch;
        }

        printf("%s\n", buf);
        fflush(stdout);
    }
}