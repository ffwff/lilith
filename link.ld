OUTPUT_FORMAT(elf32-i386)
ENTRY(_start)
SECTIONS
{
    . = 1M;
    .text BLOCK(4K) : ALIGN(4K)
    {
        kernel_end = .;
        *(.text)
        kernel_start = .;
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
    . = ALIGN(4k);
}
