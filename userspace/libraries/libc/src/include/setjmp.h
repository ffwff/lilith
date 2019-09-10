#ifndef _LIBC_SETJMP_H
#define _LIBC_SETJMP_H

struct __jmp_buf {
    unsigned long registers[6];
};

typedef struct __jmp_buf jmp_buf[1];
int setjmp(jmp_buf env);
void longjmp(jmp_buf env, int value);

#endif