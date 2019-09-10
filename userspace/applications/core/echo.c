#include <stdio.h>

int main(int argc, char **argv) {
    for(int i = 1; i < argc - 1; i++) {
        printf("%s ", argv[i]);
    }
    if (argc > 0)
    	printf("%s\n", argv[argc - 1]);
    return 0;
}