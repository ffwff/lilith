OBJ = \
	src/functions/arch/setjmp.o \
	$(patsubst %.c, %.o, $(wildcard src/functions/arch/shim/*)) \
	src/functions/arch/crt0.o \
	libc.cr.o
CRYSTAL_SRC = $(wildcard src/*.cr) $(wildcard src/functions/*.cr)
MATH_SRC=$(wildcard src/functions/math/*.cr)
ARCH=i386-elf-lilith
AR = $(ARCH)-ar
CC = $(ARCH)-gcc
AS = $(ARCH)-as
CR=$(shell pwd)/../../toolchain/crystal/.build/crystal
CRFLAGS=--cross-compile --target i686-elf --prelude ./prelude.cr
CCFLAGS = -Isrc/include -nostdlib

ifeq ($(RELEASE),1)
CRFLAGS += --release
CCFLAGS += -O2
else
CRFLAGS += -d
CCFLAGS += -g
endif

libc.a: $(OBJ)
	$(AR) rcs $@ $^

libm.a: $(MATH_SRC)
	FREESTANDING=1 $(CR) build $(CRFLAGS) src/math.cr -o math.cr
	$(AR) rcs $@ math.cr.o

libc.cr.o: $(CRYSTAL_SRC)
	FREESTANDING=1 $(CR) build $(CRFLAGS) src/main.cr -o libc.cr

src/functions/arch/setjmp.o: src/functions/arch/setjmp.s
	$(AS) -o $@ $^

%.o: %.c
	$(CC) $(CCFLAGS) -c -o $@ $^

install: libc.a libm.a src/functions/arch/crt0.o
	cp $^ $(LIBDIR)
	cp -r src/include/* $(INCLUDEDIR)

clean:
	rm -f *.o libc.a libm.a
	rm -f src/**/*.o
	rm -f src/**/**/*.o