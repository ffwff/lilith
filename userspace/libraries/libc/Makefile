ARCH ?=
CPU = $(shell echo $(ARCH) | cut -d'-' -f1)
CRTARGET = $(shell echo $(ARCH) | sed 's/-[^-]*$$//g')

AR = $(ARCH)-ar
CC = $(ARCH)-gcc
AS = $(ARCH)-as

OBJ = \
	$(patsubst src/functions/arch/shim/%.c, .build/%.o, $(wildcard src/functions/arch/shim/*)) \
	$(patsubst src/functions/arch/asm/$(CPU)/%.s, .build/asm/%.o, $(wildcard src/functions/arch/asm/$(CPU)/*.s)) \
	.build/crt0.o .build/crti.o .build/crtn.o \
	.build/libc.cr.o
MATH_OBJ = \
	$(patsubst src/functions/arch/asm/$(CPU)/math/%.s, .build/asm/%.o, $(wildcard src/functions/arch/asm/$(CPU)/math/*))

CRYSTAL_SRC = $(wildcard src/*.cr) $(wildcard src/functions/*.cr)
MATH_SRC=$(wildcard src/functions/math/*.cr)

# TODO: not hard code CR
CR=$(shell pwd)/../../../toolchain/crystal/.build/crystal

CRFLAGS=--cross-compile --target $(CRTARGET) --prelude ./prelude.cr -Ddisable_overflow
CCFLAGS = -Isrc/include -nostdlib -Wall

ifeq ($(RELEASE),1)
CRFLAGS += --release
CCFLAGS += -O2 -g
else
CRFLAGS += -d
CCFLAGS += -g
endif

libc.a: .build $(OBJ)
	$(AR) rcs $@ $(OBJ)

libm.a: $(MATH_SRC) $(MATH_OBJ)
	FREESTANDING=1 $(CR) build $(CRFLAGS) src/math.cr -o .build/math.cr
	$(AR) rcs $@ .build/math.cr.o $(MATH_OBJ)

.build:
	mkdir -p .build/asm

.build/libc.cr.o: $(CRYSTAL_SRC)
	FREESTANDING=1 $(CR) build $(CRFLAGS) src/main.cr -o .build/libc.cr

.build/asm/%.o: src/functions/arch/asm/$(CPU)/%.s
	$(AS) -o $@ $^

.build/asm/%.o: src/functions/arch/asm/$(CPU)/math/%.s
	$(AS) -o $@ $^

.build/%.o: src/functions/arch/%.c
	$(CC) $(CCFLAGS) -c -o $@ $^

.build/%.o: src/functions/arch/shim/%.c
	$(CC) $(CCFLAGS) -c -o $@ $^

install: libc.a libm.a $(wildcard .build/crt*.o)
	cp $^ $(LIBDIR)
	cp -r src/include/* $(INCLUDEDIR)

clean:
	rm -f *.o libc.a libm.a
	rm -rf .build
