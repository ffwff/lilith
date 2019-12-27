ARCH=x86_64-elf
LLVM_ARCH=x86-64
AS=$(ARCH)-as
LD=$(ARCH)-ld

ARCH32=i686-elf
AS32=$(ARCH32)-as
LD32=$(ARCH32)-ld
CR=toolchain/crystal/.build/crystal
LLC=llc

CRFLAGS=-Dkernel --cross-compile --target $(ARCH) --prelude ./prelude.cr --error-trace --mcmodel kernel --mno-red-zone -Ddisable_overflow --freestanding --no-finalizers
ASFLAGS=-Isrc/asm/x64
LDFLAGS=-T link64.ld
KERNEL_OBJ=build/main.o build/boot.o
KERNEL_SRC=build $(wildcard src/*.cr src/*/*.cr)

DRIVE_IMG = disk.img

ifeq ($(NO_CPUEX),1)
	CRFLAGS += -Dno_cpuex
endif

ifeq ($(DEBUG_GC),1)
	CRFLAGS += -Ddebug_gc
endif

ifeq ($(RECORD_CLI),1)
	CRFLAGS += -Drecord_cli
endif

ifeq ($(RELEASE),1)
	CRFLAGS += --release
else
	CRFLAGS += -d
endif

QEMU = qemu-system-x86_64

QEMUFLAGS += \
	-monitor telnet:127.0.0.1:7777,server,nowait \
	-m 512M \
	-serial stdio \
	-no-shutdown -no-reboot \
	-vga std

ifeq ($(KVM),1)
	QEMUFLAGS += -enable-kvm
endif

ifneq ($(shell cat /proc/cpuinfo | grep pdpe1gb | wc -l),0)
QEMUFLAGS += -cpu SandyBridge,+pdpe1gb
endif

GDB = /usr/bin/gdb

.PHONY: kernel src/asm/bootstrap.s qemu install_kernel_to_disk
all: build/kernel

build:
	mkdir -p build

build/main.o: $(KERNEL_SRC)
	@echo "CR src/main.cr"
	@$(CR) build $(CRFLAGS) src/main.cr -o build/main

build/boot.o: src/asm/x64/boot.s build/fonts
	@echo "AS $<"
	@$(AS) $(ASFLAGS) $< -o $@

build/fonts:
	python extern/gen-fonts.py

build/kernel64: $(KERNEL_OBJ)
	@echo "LD64 $^ => $@"
	@$(LD) $(LDFLAGS) -o $@ $^

# bootstrapping code
build/kernel: build/bootstrap.o
	@echo "LD $^ => $@"
	@$(LD32) -T link.ld -o $@ build/bootstrap.o

build/kernel64.bin: build/kernel64
	objcopy --output-target=binary $< $@

build/bootstrap.o: src/asm/bootstrap.s build/kernel64.bin
	@echo "AS32 $<"
	$(AS32) $< -o $@

#
run: build/kernel
	-$(QEMU) -kernel $^ $(QEMUFLAGS)

run_img: build/kernel
	$(QEMU) -kernel build/kernel $(QEMUFLAGS) -hda $(DRIVE_IMG)

rungdb: build/kernel
	$(QEMU) -S -kernel $^ $(QEMUFLAGS) -gdb tcp::9000 &
	$(GDB) -quiet -ex 'target remote localhost:9000' -ex 'b kmain' -ex 'continue' build/kernel

rungdb_img:
	$(QEMU) -kernel build/kernel $(QEMUFLAGS) -hda $(DRIVE_IMG) -S -gdb tcp::9000 &
	sleep 0.1s && $(GDB) -quiet \
		-ex 'target remote localhost:9000' \
		-ex 'hb kmain' \
		-ex 'continue' \
		-ex 'disconnect' \
		-ex 'set arch i386:x86-64:intel' \
		-ex 'target remote localhost:9000' \
		build/kernel64

rungdb_img_user: build/kernel
	$(QEMU) -kernel build/kernel $(QEMUFLAGS) -hda $(DRIVE_IMG) -S -gdb tcp::9000 &
	$(GDB) -quiet \
		-ex 'target remote localhost:9000' \
		-ex 'hb main' \
		-ex 'continue' \
		-ex 'disconnect' \
		-ex 'set arch i386' \
		-ex 'target remote localhost:9000' \
		$(FILE)
	-@pkill qemu

runiso: os.iso
	$(QEMU) -S -boot d -cdrom os.iso -hda $(DRIVE_IMG) $(QEMUFLAGS) -gdb tcp::9000 &
	sleep 0.1s && $(GDB) -quiet \
		-ex 'set arch i386:x86-64:intel' \
		-ex 'target remote localhost:9000' \
		-ex 'hb kmain' \
		-ex 'continue' \
		-ex 'disconnect' \
		-ex 'set arch i386:x86-64:intel' \
		-ex 'target remote localhost:9000' \
		build/kernel64
	-@pkill qemu

rundisk:
	$(QEMU) -S -hda $(DRIVE_IMG) $(QEMUFLAGS) -gdb tcp::9000 &
	sleep 0.1s && $(GDB) -quiet \
		-ex 'set arch i386:x86-64:intel' \
		-ex 'target remote localhost:9000' \
		-ex 'hb kmain' \
		-ex 'continue' \
		-ex 'disconnect' \
		-ex 'set arch i386:x86-64:intel' \
		-ex 'target remote localhost:9000' \
		build/kernel64
	-@pkill qemu

os.iso: build/kernel
	rm -rf /tmp/iso && mkdir -p /tmp/iso/boot/grub
	cp $^ /tmp/iso
	cp grub.cfg /tmp/iso/boot/grub
	cp build/kernel /tmp/iso/boot/
	grub-mkrescue -o os.iso /tmp/iso

$(DRIVE_IMG):
	dd if=/dev/zero of=$(DRIVE_IMG) bs=512 count=102400
	printf "\
o\n\
n\n\
p\n\
1\n\
\n\n\
\n\
t\n\
6\n\
w\n\
" | fdisk $(DRIVE_IMG)
	sudo losetup /dev/loop0 $(DRIVE_IMG)
	sudo losetup /dev/loop1 $(DRIVE_IMG) -o 1048576
	sudo mkfs.fat -F16 /dev/loop1
	sudo mount /dev/loop1 /mnt
	sudo grub-install --root-directory=/mnt --no-floppy --modules="normal part_msdos fat multiboot" /dev/loop0
	sudo cp grub.cfg /mnt/boot/grub/
	sudo umount /mnt
	sudo losetup -D /dev/loop0
	sudo losetup -D /dev/loop1

install_kernel_to_disk: build/kernel
	sudo losetup -P /dev/loop0 $(DRIVE_IMG)
	sudo mount /dev/loop0p1 /mnt
	sudo cp $^ /mnt/boot/kernel
	sudo umount /mnt
	sudo losetup -D /dev/loop0

distro: $(DRIVE_IMG) install_kernel_to_disk
	./pkgs/missio build libc libz libpng
	./pkgs/missio install base main adam core wm lua mruby kilo

clean:
	rm -f build/*
	rm -f kernel

# crystal
toolchain/crystal:
	cd toolchain && git clone https://github.com/ffwff/crystal && cd crystal && git checkout lilin

$(CR): toolchain/crystal
	cd toolchain/crystal && make release=1

# qemu
qemu:
	cd /tmp && \
	git clone https://github.com/qemu/qemu && \
	cd qemu && \
	git checkout stable-2.8 && \
	patch -p1 < $(PWD)/toolchain/qemu.patch && \
	mkdir build && cd build && \
	../configure --prefix=/usr/local \
		--target-list=x86_64-softmmu \
		--python=/usr/bin/python2 \
		--disable-werror \
		--disable-gnutls --disable-nettle --disable-tpm && \
	make -j$(shell nproc) && sudo make install
