OBJ = \
	stub/functions/setjmp.o stub/functions/syscalls.o stub.cr.o \
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
CRYSTAL_SRC=$(wildcard stub/*.cr) $(wildcard stub/functions/*.cr)
ARCH=i386-elf-lilith
AR = $(ARCH)-ar
CC = $(ARCH)-gcc
AS = $(ARCH)-as
CR=$(shell pwd)/../../toolchain/crystal/.build/crystal
CRFLAGS=--cross-compile --target i686-elf --prelude ./prelude.cr
CCFLAGS = -Ipdclib/include \
	-Istub/include -Istub/include/pdclib \
	-nostdinc -nostdlib

ifeq ($(RELEASE),1)
CRFLAGS += --release
CCFLAGS += -O2
else
CRFLAGS += -d
CCFLAGS += -g
endif

libc.a: $(OBJ)
	$(AR) rcs $@ $^

libm.a: stub/math.cr
	FREESTANDING=1 $(CR) build $(CRFLAGS) $< -o math.cr
	$(AR) rcs $@ math.cr.o

stub.cr.o: $(CRYSTAL_SRC)
	FREESTANDING=1 $(CR) build $(CRFLAGS) stub/main.cr -o stub.cr

stub/functions/setjmp.o: stub/functions/setjmp.s
	$(AS) -o $@ $^

%.o: %.c
	$(CC) $(CCFLAGS) -c -o $@ $^

install: libc.a libm.a crt0.o
	cp libc.a libm.a crt0.o $(LIBDIR)
	cp -r pdclib/include/* $(INCLUDEDIR)
	cp -r stub/include/* $(INCLUDEDIR)

clean:
	rm -f *.o libc.a libm.a
	rm -f stub/**/*.o
	rm -f stub/**/**/*.o