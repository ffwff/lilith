PREFIX ?= /usr
INCLUDEDIR ?= $(PREFIX)/include
LIBDIR ?= $(PREFIX)/lib
DEFAULT: libgui.a
.PHONY: install clean

.build:
	mkdir -p $@

.build/%.o: %.c .build
	$(CC) -g -O2 -Wall $(CFLAGS) -c $< -o $@

libgui.a: $(patsubst %.c, .build/%.o, $(wildcard ./*.c))
	ar rcs $@ $^

install: $(wildcard ./gui/*.h) libgui.a
	cp -r gui $(INCLUDEDIR)
	cp gui.h $(INCLUDEDIR)
	cp libgui.a $(LIBDIR)

clean:
	rm -f .build/*.o *.a
