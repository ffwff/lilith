#include <stdio.h>
#include <syscalls.h>

int main() {
    while(1) {
        char buf[256]={0};
        printf("> ");
        fflush(stdout);

        int j = 0;
        for(int i = 0; i < sizeof(buf)-1; i++, j++) {
            char ch = fgetc(stdin);
            if(ch == '\n') break;
            buf[i] = ch;
        }
        buf[j] = 0;

        printf("[%s]\n", buf);
        spawn(buf);
        fflush(stdout);
    }
}