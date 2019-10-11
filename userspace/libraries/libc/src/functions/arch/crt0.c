unsigned char __data_start __attribute__ ((used, section(".data")));
unsigned char *_data = &__data_start;

unsigned char __bss_start __attribute__ ((used, section(".bss")));
unsigned char *_bss = &__bss_start;
