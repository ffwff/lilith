OUTPUT_FORMAT(elf32-i386)
ENTRY(_start)
SECTIONS
{
    . = 1M;

    _TEXT_START = .;
    .text BLOCK(4K) : ALIGN(4K)
    {
        *(.multiboot)
        *(.text)
    }
    . = ALIGN(4K);
    _TEXT_END = .;

    . = ALIGN(4K);
    _DATA_START = .;
    .data BLOCK(4K) : ALIGN(4K)
    {
        *(.data)

        text_start = .; LONG(_TEXT_START)
        text_end = .;   LONG(_TEXT_END)
        data_start = .; LONG(_DATA_START)
        data_end = .;   LONG(_DATA_END)
        kernel_end = .; LONG(_KERNEL_END)
    }
    .bss BLOCK(4K) : ALIGN(4K)
    {
        *(.bss)
    }
    . = ALIGN(4K);
    _DATA_END = .;

    .stack BLOCK(4K) : ALIGN(4K)
    {
        *(.stack)
    }
    . = ALIGN(4K);
    _KERNEL_END = .;
}
