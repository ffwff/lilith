NPROC=$(shell nproc)

binutils:
	git clone https://github.com/bminor/binutils-gdb binutils
	cd binutils && \
	git checkout binutils-2_32-branch && \
	patch -p1 < $(PWD)/patches/binutils.patch >/dev/null

build_binutils: binutils
	cd binutils && \
	mkdir -p build && cd build && \
	../configure --target=i386-elf-lilith --disable-nls --disable-werror --prefix=$(PWD)/tools --disable-gdb --disable-gprof --with-system-zlib --without-selinux && \
	make -j$(NPROC) && make install

# gcc
gcc:
	git clone git://gcc.gnu.org/git/gcc.git gcc
	cd gcc && \
	git checkout 4ac50a4913e && \
	patch -p1 < $(PWD)/patches/gcc.patch >/dev/null

build_gcc: gcc
	cd gcc && \
	mkdir -p build && cd build && \
	../configure                  \
		--target=i386-elf-lilith  \
		--prefix=$(PWD)/tools     \
		--with-newlib             \
		--without-headers         \
		--with-glibc-version=2.11 \
		--disable-nls             \
		--disable-shared          \
		--disable-multilib        \
		--disable-decimal-float   \
		--disable-threads         \
		--disable-libatomic       \
		--disable-libgomp         \
		--disable-libmpx          \
		--disable-libquadmath     \
		--disable-libssp          \
		--disable-libvtv          \
		--disable-libstdcxx       \
		--enable-languages=c && \
	make -j$(NPROC)

#
cparser:
	git clone --recursive https://github.com/libfirm/cparser
	cd cparser && \
	git checkout 7703641 && \
	patch -p1 < $(PWD)/patches/cparser.patch >/dev/null

build_cparser: cparser
	cd cparser && \
	make PREFIX=$(PWD)/tools variant=optimize -j$(nproc) install
	ln -s ./cparser $(PWD)/tools/bin/i386-elf-lilith-cc

#
automake-1.12:
	wget https://ftp.gnu.org/gnu/automake/automake-1.12.tar.gz
	tar xf automake-1.12.tar.gz

build_automake: automake-1.12
	cd automake-1.12 && \
	mkdir -p build && cd build && \
	../configure --prefix=$(PWD)/tools && \
	make -j$(NPROC) && make install

#
autoconf-2.64:
	wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.64.tar.gz
	tar xf autoconf-2.64.tar.gz

build_autoconf: autoconf-2.64
	cd autoconf-2.64 && \
	mkdir -p build && cd build && \
	../configure --prefix=$(PWD)/tools && \
	make -j$(NPROC) && make install
