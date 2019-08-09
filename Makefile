ARCH=x86_64-elf
AS=$(ARCH)-as
LD=$(ARCH)-ld
ARCH32=i686-elf
AS32=$(ARCH32)-as
LD32=$(ARCH32)-ld
CR=toolchain/crystal/.build/crystal
CRFLAGS=--cross-compile --target $(ARCH) --prelude ./prelude.cr --error-trace
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
	-vga std \
	-d int

GDB = /usr/local/bin/gdb

.PHONY: kernel src/asm/bootstrap.s
all: build/kernel

build/main.cr.o: $(KERNEL_SRC)
	@echo "CR src/main.cr"
	@FREESTANDING=1 $(CR) build $(CRFLAGS) src/main.cr -o build/main.cr

build/%.o: src/asm/x64/%.s
	@echo "AS $<"
	@$(AS) $^ -o $@ -Isrc/asm/x64

build/kernel64: $(KERNEL_OBJ)
	@echo "LD64 $^ => $@"
	@$(LD) -T link64.ld -o $@ $^

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
		-ex 'continue' \
		-ex 'disconnect' \
		-ex 'set arch i386:x86-64:intel' \
		-ex 'target remote localhost:9000' \
		build/kernel64
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
