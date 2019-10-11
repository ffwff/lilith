unsigned char __data_end __attribute__ ((weak, used, section(".data")));
unsigned char __bss_end __attribute__ ((weak, used, section(".bss")));
unsigned char *_data_end __attribute__((weak)) = &__data_end;
unsigned char *_bss_end __attribute__((weak)) = &__bss_end;
