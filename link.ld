OUTPUT_FORMAT(elf32-i386)
ENTRY(_start)
SECTIONS
{
    . = 1M;
    .text BLOCK(4K) : ALIGN(4K)
    {
        _TEXT_START = .;
        *(.multiboot)
        *(.text)
        _TEXT_END = .;
    }
    . = . + 0x1000;
    _DATA_START = .;
    .data BLOCK(4K) : ALIGN(4K)
    {
        *(.data)
    }
    .bss BLOCK(4K) : ALIGN(4K)
    {
        *(.bss)
    }
    _DATA_END = .;
    . = . + 0x1000;
    .stack BLOCK(4K) : ALIGN(4K)
    {
        *(.stack)
    }
    . = ALIGN(4K) + 0x1000;
    _KERNEL_END = .;
}
