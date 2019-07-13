if [[ "x$CC" = "x" ]]; then
    CC=clang
fi

ARCH=i686-elf
$CC -c -o $1.o $1 -target $ARCH -nostdlib -nostdinc -O2 -mno-sse
ld -m elf_i386 -T link.ld -o $(basename "$1" .c).bin $1.o