#include <stdio.h>

int main(int argc, char **argv) {
    if(argc < 2) {
        printf("usage: %s filename\n", argv[0]);
        return 1;
    }
    FILE *f = fopen(argv[1], "r");
    if(f == 0) {
        printf("unable to open file\n");
        return 1;
    }
    char buf[1024];
    fread(buf, 1, sizeof(buf), f);
    fputs(buf, stdout);
}