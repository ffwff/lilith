#ifndef _LIBC_DIRENT_H
#define _LIBC_DIRENT_H

typedef unsigned long ino_t;
typedef void DIR;

struct dirent {
    /* Inode number */
    ino_t d_ino;
    /* Length of this record */
    unsigned short d_reclen;
    /* Type of file; not supported by all filesystem types */
    unsigned char d_type;
    /* Null-terminated filename */
    char d_name[256];
};

DIR *opendir(const char *dirname);
int closedir(DIR *dirp);
struct dirent* readdir(DIR *dirp);

#endif _PDCLIB_DIRENT_H