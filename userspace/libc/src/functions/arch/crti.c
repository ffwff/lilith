typedef void (*func_ptr)(void);

extern func_ptr __init_array_start[0], __init_array_end[0];
extern func_ptr __fini_array_start[0], __fini_array_end[0];

void _init(void) {
    for (func_ptr* func = __init_array_start; func != __init_array_end; func++)
        (*func)();
}

void _fini(void) {
    for (func_ptr* func = __fini_array_start; func != __fini_array_end; func++)
        (*func)();
}
