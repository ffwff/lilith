OUTPUT_FORMAT(binary)
ENTRY(_start)
SECTIONS
{
    . = 0x80000000;
    .text : {
        *(.text)
    }
    .data : {
        *(.data)
    }
}
