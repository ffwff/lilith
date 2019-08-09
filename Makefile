ARCH=i686-elf
ARCH64=x86_64-elf
AS=$(ARCH)-as
AS64=$(ARCH64)-as
LD=$(ARCH)-ld
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

QEMU = qemu-system-x86_64

QEMUFLAGS += \
	-rtc base=localtime \
	-monitor telnet:127.0.0.1:7777,server,nowait \
	-m 2G \
	-serial stdio \
	-no-shutdown -no-reboot \
	-vga std

GDB = /usr/local/bin/gdb

.PHONY: kernel
all: build/kernel

build/main.cr.o: $(KERNEL_SRC)
	@echo "CR src/main.cr"
	@FREESTANDING=1 $(CR) build $(CRFLAGS) src/main.cr -o build/main.cr

build/%.o: src/asm/%.s
	@echo "AS $<"
	@$(AS) $^ -o $@

build/boot64.o: boot64.s
	@echo "AS64 $<"
	@$(AS64) $^ -o $@

build/kernel: $(KERNEL_OBJ)
	@echo "LD $^ => $@"
	@$(LD) $(LDFLAGS) -o $@ $^ $(LIBGCC)

#
run: build/kernel
	-$(QEMU) -kernel $^ $(QEMUFLAGS)

run_img: build/kernel drive.img
	$(QEMU) -kernel build/kernel $(QEMUFLAGS) -hda drive.img

rungdb: build/kernel
	$(QEMU) -S -kernel $^ $(QEMUFLAGS) -gdb tcp::9000 &
	$(GDB) -quiet -ex 'target remote localhost:9000' -ex 'b kmain' -ex 'continue' build/kernel
	-@pkill qemu

rungdb_img: build/kernel drive.img
	$(QEMU) -kernel build/kernel $(QEMUFLAGS) -hda drive.img -S -gdb tcp::9000 &
	sleep 0.1s && $(GDB) -quiet \
		-ex 'set arch i386:x86-64:intel' \
		-ex 'target remote localhost:9000' \
		-ex 'hb kmain' \
		-ex 'hb breakpoint' \
		-ex 'continue' \
		-ex 'disconnect' \
		-ex 'set arch i386:x86-64:intel' \
		-ex 'target remote localhost:9000' \
		build/kernel
	-@pkill qemu

rungdb_img_custom: build/kernel drive.img
	$(QEMU) -kernel build/kernel $(QEMUFLAGS) -hda drive.img -S -gdb tcp::9000 &
	$(GDB) -quiet -ex 'target remote localhost:9000' $(GDB_ARGS)
	-@pkill qemu

runiso: os.iso
os.iso: build/kernel
	rm -rf /tmp/iso && mkdir -p /tmp/iso/boot/grub
	cp $^ /tmp/iso
	cp grub.cfg /tmp/iso/boot/grub
	grub-mkrescue -o os.iso /tmp/iso
	$(QEMU) -S -cdrom os.iso $(QEMUFLAGS) -gdb tcp::9000 &
	$(GDB) -quiet -ex 'target remote localhost:9000' -ex 'b kmain' -ex 'continue' build/kernel
	-@pkill qemu

clean:
	rm -f build/*.o
	rm -f kernel

# debug
toolchain/crystal:
	cd toolchain && git clone https://github.com/crystal-lang/crystal && \
	cd crystal && git checkout 0.30.0 && \
	patch -p1 < ../crystal.patch

$(CR): toolchain/crystal
	cd toolchain/crystal && make release=1
