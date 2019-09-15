PREFIX ?= /usr
INCLUDEDIR ?= $(PREFIX)/include
LIBDIR ?= $(PREFIX)/lib
DEFAULT: canvas.a
.PHONY: install clean

%.o: %.c
	$(CC) -g -O2 -Wall $(CFLAGS) -c $^ -o $@

libgui.a: $(patsubst %.c, %.o, $(wildcard ./*.c))
	ar rcs $@ $^

install: gui.h libgui.a
	cp gui.h $(INCLUDEDIR)
	cp libgui.a $(LIBDIR)

clean:
	rm -f *.a *.o
