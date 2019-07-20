ARCH=i686-elf
AS=$(ARCH)-as
LD=$(ARCH)-ld
CC=clang
LIBGCC=$(shell $(ARCH)-gcc -print-libgcc-file-name)
LDFLAGS=-m elf_i386 -T link.ld
CR=$(shell pwd)/toolchain/crystal/.build/crystal
#CR=crystal
CCFLAGS=-c -g -target $(ARCH) -nostdlib -nostdinc \
	-fno-stack-protector -ffreestanding -O3 \
	-Wall -Wno-unused-function -Wno-unknown-pragmas \
	-mno-sse
CRFLAGS=--cross-compile --emit llvm-ir --target $(ARCH) --prelude empty
KERNEL_OBJ=$(patsubst src/arch/%.c,build/arch.%.o,$(wildcard src/arch/*.c)) \
	build/boot.o build/main.o
LCCFLAGS=
STRIP=false

ifeq ($(RELEASE),1)
	CRFLAGS += --release
	STRIP=true
	LCCFLAGS += -O3
else
	CRFLAGS += -d
	LCCFLAGS += -O0
endif

QEMUFLAGS ?=

QEMUFLAGS += \
	-rtc base=localtime \
	-monitor telnet:127.0.0.1:7777,server,nowait \
	-m 64M \
	-serial stdio \
	-no-shutdown -no-reboot

.PHONY: kernel
all: build/kernel

build/main.bc: src/main.cr
	@echo "CR $<"
	cd build && $(CR) build $(CRFLAGS) $(shell pwd)/$<
	-$(STRIP) && crystal toolchain/strip.cr build/main.ll build/main.bc

build/main.o: build/main.bc
	llc -mtriple=$(ARCH) -filetype=obj -o $@ $< $(LCCFLAGS)

build/arch.%.o: src/arch/%.c
	@echo "CC $<"
	@$(CC) $(CCFLAGS) -Isrc -o $@ $<

build/boot.o: boot.s
	@echo "AS $<"
	@$(AS) $^ -o $@

build:
	mkdir -p build

build/kernel: build $(KERNEL_OBJ)
	@echo "LD $(KERNEL_OBJ) => $@"
	@$(LD) $(LDFLAGS) -o $@ $(KERNEL_OBJ) $(LIBGCC)
	-$(STRIP) && strip $@

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
	gdb -quiet -ex 'target remote localhost:9000' -ex 'b kmain' -ex 'b breakpoint' -ex 'continue' build/kernel
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
#drive.img:
#	qemu-img create -f raw $@ 50M

# toolchain
toolchain/crystal:
	cd toolchain/ && \
	git clone https://github.com/crystal-lang/crystal && \
	cd crystal && git checkout fbfe8b6 && \
	patch -p1 <../crystal.

$(CR): toolchain/crystal
	cd toolchain/crystal && make