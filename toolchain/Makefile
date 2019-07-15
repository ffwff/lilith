.PHONY: build_binutils

binutils:
	git clone https://github.com/bminor/binutils-gdb
	cd binutils-gdb && \
	git checkout binutils-2_32-branch && \
	patch -p1 < $(PWD)/patches/binutils.patch >/dev/null

build_binutils: binutils
	cd binutils && \
	mkdir -p build && cd build && \
	../configure --target=i386-elf-lilith --disable-nls --disable-werror --prefix=$(PWD)/tools --disable-gdb --disable-gprof --with-system-zlib --without-selinux && \
	make -j$(nproc)