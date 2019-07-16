OBJ = \
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
		$(wildcard stub/functions/*.c) \
	)
AR = i386-elf-lilith-ar
CC = i386-elf-lilith-cc
CCFLAGS = -Ipdclib/include \
	-Istub/include -Istub/include/pdclib \
	-nostdinc -nostdlib

libc.a: $(OBJ)
	$(AR) rcs $@ $^

libgcc.a:
	cp `i686-elf-gcc -print-libgcc-file-name` $@

%.o: %.c
	$(CC) $(CCFLAGS) -c -o $@ $^
