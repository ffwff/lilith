OUTPUT_FORMAT(elf32-i386)
ENTRY(_start)
SECTIONS {
    . = 0x80000000;
    .text : {
    _TEXT_START = .;
        *(.text)
    _TEXT_END = .;
    }
    .data : {
        *(.data)
    }
}
