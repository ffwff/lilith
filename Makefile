ARCH=i686-elf
AS=$(ARCH)-as
LD=$(ARCH)-ld
CC=clang
LIBGCC=$(shell $(ARCH)-gcc -print-libgcc-file-name)
LDFLAGS=-m elf_i386 -T link.ld
CR=toolchain/crystal/.build/crystal
CRFLAGS=--cross-compile --target $(ARCH) --mcpu=pentium4 --prelude ./prelude.cr
KERNEL_OBJ=build/main.cr.o build/boot.o
KERNEL_SRC=$(wildcard src/*.cr src/*/*.cr)

ifeq ($(RELEASE),1)
	CRFLAGS += --release
else
	CRFLAGS += -d
endif

QEMUFLAGS ?=

QEMUFLAGS += \
	-rtc base=localtime \
	-monitor telnet:127.0.0.1:7777,server,nowait \
	-m 64M \
	-serial stdio \
	-no-shutdown -no-reboot \
	-vga std -device VGA

.PHONY: kernel
all: build/kernel

build/main.cr.o: $(KERNEL_SRC)
	@echo "CR src/main.cr"
	@FREESTANDING=1 $(CR) build $(CRFLAGS) src/main.cr -o build/main.cr

build/boot.o: boot.s
	@echo "AS $<"
	@$(AS) $^ -o $@

build/kernel: $(KERNEL_OBJ)
	@echo "LD $^ => $@"
	@$(LD) $(LDFLAGS) -o $@ $^ $(LIBGCC)

#
run: build/kernel
	-qemu-system-i386 -kernel $^ $(QEMUFLAGS)

run_img: build/kernel drive.img
	qemu-system-i386 -kernel build/kernel $(QEMUFLAGS) -hda drive.img

rungdb: build/kernel
	qemu-system-i386 -S -kernel $^ $(QEMUFLAGS) -gdb tcp::9000 &
	gdb -quiet -ex 'target remote localhost:9000' -ex 'b kmain' -ex 'continue' build/kernel
	-@pkill qemu

rungdb_img: build/kernel drive.img
	qemu-system-i386 -kernel build/kernel $(QEMUFLAGS) -hda drive.img -S -gdb tcp::9000 &
	sleep 0.1s && gdb -quiet -ex 'target remote localhost:9000' -ex 'b kmain' -ex 'b breakpoint' -ex 'continue' build/kernel
	-@pkill qemu

rungdb_img_custom: build/kernel drive.img
	qemu-system-i386 -kernel build/kernel $(QEMUFLAGS) -hda drive.img -S -gdb tcp::9000 &
	gdb -quiet -ex 'target remote localhost:9000' $(GDB_ARGS)
	-@pkill qemu

runiso: os.iso
os.iso: build/kernel
	rm -rf /tmp/iso && mkdir -p /tmp/iso/boot/grub
	cp $^ /tmp/iso
	cp grub.cfg /tmp/iso/boot/grub
	grub-mkrescue -o os.iso /tmp/iso
	qemu-system-i386 -S -cdrom os.iso $(QEMUFLAGS) -gdb tcp::9000 &
	gdb -quiet -ex 'target remote localhost:9000' -ex 'b kmain' -ex 'continue' build/kernel
	-@pkill qemu

clean:
	rm -f build/*.o
	rm -f kernel

# debug
toolchain/crystal:
	cd toolchain && git clone https://github.com/crystal-lang/crystal && \
	cd crystal && git checkout fbfe8b62f && \
	patch -p1 < ../crystal.patch

$(CR): toolchain/crystal
	cd toolchain/crystal && make release=1
