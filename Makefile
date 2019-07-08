ARCH=i686-elf
AS=$(ARCH)-as
LD=$(ARCH)-ld
CC=clang
LIBGCC=$(shell $(ARCH)-gcc -print-libgcc-file-name)
LDFLAGS=-m elf_i386 -T link.ld
CCFLAGS=-c -g -target $(ARCH) -nostdlib -nostdinc \
	-fno-stack-protector -ffreestanding -O2 \
	-Wall -Wno-unused-function -Wno-unknown-pragmas \
	-mno-sse
CRFLAGS=--cross-compile --target $(ARCH) --prelude empty -d
KERNEL_OBJ=build/main.cr.o \
	$(patsubst src/arch/%.c,build/arch.%.o,$(wildcard src/arch/*.c)) \
	build/boot.o


QEMUFLAGS ?=

QEMUFLAGS += \
	-rtc base=localtime \
	-monitor telnet:127.0.0.1:7777,server,nowait \
	-m 64M \
	-serial stdio \
	-no-shutdown -no-reboot

.PHONY: kernel
all: build/kernel

build/main.cr.o: src/main.cr
	@echo "CR $<"
	@crystal build $(CRFLAGS) $< -o build/main.cr

build/arch.%.o: src/arch/%.c
	@echo "CC $<"
	@$(CC) $(CCFLAGS) -Isrc -o $@ $<

build/boot.o: boot.s
	@echo "AS $<"
	@$(AS) $^ -o $@

build/kernel: $(KERNEL_OBJ)
	@echo "LD $^ => $@"
	@$(LD) $(LDFLAGS) -o $@ $^ $(LIBGCC)

#
run: build/kernel
	-qemu-system-i386 -kernel $^ $(QEMUFLAGS)

rungdb: build/kernel
	qemu-system-i386 -S -kernel $^ $(QEMUFLAGS) -gdb tcp::9000 &
	gdb -quiet -ex 'target remote localhost:9000' -ex 'b kmain' -ex 'continue' build/kernel
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
