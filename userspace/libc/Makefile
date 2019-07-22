OBJ = \
	stub/functions/syscalls.o stub.cr.o \
	$(patsubst %.c,%.o, \
		$(wildcard pdclib/functions/_PDCLIB/*.c) \
		$(wildcard pdclib/functions/ctype/*.c) \
		$(wildcard pdclib/functions/inttypes/*.c) \
		$(wildcard pdclib/functions/locale/*.c) \
		$(wildcard pdclib/functions/stdio/*.c) \
		$(wildcard pdclib/functions/stdlib/*.c) \
		$(wildcard pdclib/functions/string/*.c) \
		$(wildcard pdclib/functions/time/*.c) \
	) \
	$(patsubst %.c,%.o, \
		$(wildcard stub/functions/_PDCLIB/*.c) \
	)
AR = i386-elf-lilith-ar
CC = i386-elf-lilith-gcc
CR=$(shell pwd)/../../toolchain/crystal/.build/crystal
CRFLAGS=--cross-compile --target i686-elf -d --prelude ./prelude.cr
CCFLAGS = -Ipdclib/include \
	-Istub/include -Istub/include/pdclib \
	-nostdinc -nostdlib -g

libc.a: $(OBJ)
	$(AR) rcs $@ $^

stub.cr.o: stub/main.cr
	$(CR) build $(CRFLAGS) $< -o stub.cr

%.o: %.c
	$(CC) $(CCFLAGS) -c -o $@ $^

install: libc.a crt0.o
	cp libc.a crt0.o $(LIBDIR)
	cp -r pdclib/include/* $(INCLUDEDIR)
	cp -r stub/include/* $(INCLUDEDIR)

clean:
	rm -f *.o libc.a
	rm -f stub/**/*.o
	rm -f stub/**/**/*.o