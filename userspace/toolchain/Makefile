.PHONY: build_binutils

binutils:
	git clone https://github.com/bminor/binutils-gdb binutils
	cd binutils && \
	git checkout binutils-2_32-branch && \
	patch -p1 < $(PWD)/patches/binutils.patch >/dev/null

build_binutils: binutils
	cd binutils && \
	mkdir -p build && cd build && \
	../configure --target=i386-elf-lilith --disable-nls --disable-werror --prefix=$(PWD)/tools --disable-gdb --disable-gprof --with-system-zlib --without-selinux && \
	make -j$(nproc)

cparser:
	git clone --recursive https://github.com/libfirm/cparser
	cd cparser && \
	git checkout 7703641 && \
	patch -p1 < $(PWD)/patches/cparser.patch >/dev/null

build_cparser: cparser
	cd cparser && \
	make PREFIX=$(PWD)/tools variant=optimize -j$(nproc) install