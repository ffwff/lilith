OBJ = \
	$(patsubst %.c, %.o, $(wildcard src/functions/arch/shim/*)) \
	$(patsubst %.s, %.o, $(wildcard src/functions/arch/asm/i386/*.s)) \
	src/functions/arch/crt0.o src/functions/arch/crti.o  src/functions/arch/crtn.o \
	libc.cr.o
MATH_OBJ = \
	$(patsubst %.s, %.o, $(wildcard src/functions/arch/asm/i386/math/*))

CRYSTAL_SRC = $(wildcard src/*.cr) $(wildcard src/functions/*.cr)
MATH_SRC=$(wildcard src/functions/math/*.cr)

ARCH=i386-elf-lilith
AR = $(ARCH)-ar
CC = $(ARCH)-gcc
AS = $(ARCH)-as
# TODO: not hard code CR
CR=$(shell pwd)/../../../toolchain/crystal/.build/crystal

CRFLAGS=--cross-compile --target i686-elf --prelude ./prelude.cr -Ddisable_overflow
CCFLAGS = -Isrc/include -nostdlib -Wall

ifeq ($(RELEASE),1)
CRFLAGS += --release
CCFLAGS += -O2
else
CRFLAGS += -d
CCFLAGS += -g
endif

libc.a: $(OBJ)
	$(AR) rcs $@ $^

libm.a: $(MATH_SRC) $(MATH_OBJ)
	FREESTANDING=1 $(CR) build $(CRFLAGS) src/math.cr -o math.cr
	$(AR) rcs $@ math.cr.o $(MATH_OBJ)

libc.cr.o: $(CRYSTAL_SRC)
	FREESTANDING=1 $(CR) build $(CRFLAGS) src/main.cr -o libc.cr

%.o: %.s
	$(AS) -o $@ $^

%.o: %.c
	$(CC) $(CCFLAGS) -c -o $@ $^

install: libc.a libm.a $(wildcard src/functions/arch/crt*.o)
	cp $^ $(LIBDIR)
	cp -r src/include/* $(INCLUDEDIR)

clean:
	rm -f *.o libc.a libm.a
	rm -f src/**/*.o
	rm -f src/**/**/*.o
	rm -f src/**/**/**/*.o
	rm -f src/**/**/**/**/*.o
