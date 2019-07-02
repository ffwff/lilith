extern void *kernel_end;
unsigned int pmalloc_addr = 0;

void *pmalloc(unsigned int sz) {
    if (pmalloc_addr == 0) pmalloc_addr = (unsigned int)kernel_end;
    void *ptr = (void*)pmalloc_addr;
    pmalloc_addr += sz;
    return ptr;
}

void *pmalloc_a(unsigned int sz, unsigned int *addr) {
    if (pmalloc_addr == 0) pmalloc_addr = (unsigned int)kernel_end;
    if (pmalloc_addr & 0xFFFFF000) {
        pmalloc_addr = (pmalloc_addr & 0xFFFFF000) + 0x1000;
    }
    if (addr != 0) {
        *addr = pmalloc_addr;
    }
    return pmalloc(sz);
}