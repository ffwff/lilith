OUTPUT_FORMAT(elf32-i386)
ENTRY(_bootstrap_start)
SECTIONS
{
    . = 1M;

    .text BLOCK(4K) : ALIGN(4K)
    {
        *(.multiboot)
        *(.text)
    }

    . = ALIGN(4K);
    _DATA_START = .;
    .data : ALIGN(4K)
    {
        *(.data)
        . = 0x120000 - _DATA_START;
        kernel64 = .;
        *(.kernel64*)
    }
}
