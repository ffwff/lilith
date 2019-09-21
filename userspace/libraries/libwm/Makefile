PREFIX ?= /usr
INCLUDEDIR ?= $(PREFIX)/include
LIBDIR ?= $(PREFIX)/lib
DEFAULT: libwmc.a
.PHONY: install clean

%.o: %.c
	$(CC) -g -O2 -Wall $(CFLAGS) -c $^ -o $@

libwmc.a: wmc.o
	ar rcs $@ $^

install: wm.h wmc.h libwmc.a
	mkdir -p $(INCLUDEDIR)/wm
	cp wm.h wmc.h $(INCLUDEDIR)/wm
	cp libwmc.a $(LIBDIR)

clean:
	rm -f *.a *.o
