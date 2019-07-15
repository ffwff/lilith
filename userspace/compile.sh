if [[ "x$CC" = "x" ]]; then
    CC=clang
fi

ARCH=i386-elf-lilith
$CC -o $1.bin $1 -target $ARCH -nostdlib -nostdinc -O2
# ./toolchain/tools/bin/i386-elf-lilith-ld -o $(basename "$1" .c).bin $1.o