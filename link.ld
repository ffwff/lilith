OUTPUT_FORMAT(elf32-i386)
ENTRY(_start)
SECTIONS
{
    . = 1M;
    kernel_end = .;
    .text BLOCK(4K) : ALIGN(4K)
    {
        _TEXT_END = .;
        *(.text)
        _TEXT_START = .;
    }
    .data BLOCK(4K) : ALIGN(4K)
    {
        _DATA_START = .;
        *(.data)
        _DATA_END = .;
    }
    .bss BLOCK(4K) : ALIGN(4K)
    {
        _BSS_START = .;
        *(.bss)
        _BSS_END = .;
    }
    . = ALIGN(4K);
}
