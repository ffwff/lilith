#include <dirent.h>
#include <stdlib.h>

DIR *opendir(const char *dirname) {
    DIR *dirp = malloc(sizeof(DIR));
    dirp->fd = open(dirname);
    if (dirp->fd == 0)
        return 0;
    return dirp;
}

int closedir(DIR *dirp) {
    close(dirp->fd);
    free(dirp);
    return 1;
}

struct dirent *readdir(DIR *dirp) {

}