#ifndef _LIBC_SETJMP_H
#define _LIBC_SETJMP_H

typedef void* jmp_buf;
int setjmp(jmp_buf env);
void longjmp(jmp_buf env, int value);

#endif