#ifndef _LIBC_SETJMP_H
#define _LIBC_SETJMP_H

#ifdef __i386__
typedef unsigned long __jmp_buf[6];
#endif
#ifdef __x86_64__
typedef unsigned long __jmp_buf[8];
#endif

typedef struct __jmp_buf_tag {
	__jmp_buf __jb;
	unsigned long __fl;
	unsigned long __ss[128/sizeof(long)];
} jmp_buf[1];

int setjmp(jmp_buf env);
void longjmp(jmp_buf env, int value);

#endif
