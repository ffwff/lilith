PREFIX ?= /usr
INCLUDEDIR ?= $(PREFIX)/include
.PHONY: install

install: wm.h wmc.h
	mkdir -p $(INCLUDEDIR)/wm
	cp $^ $(INCLUDEDIR)/wm/