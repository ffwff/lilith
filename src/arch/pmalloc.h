#pragma once

void *pmalloc(unsigned int sz);
void *pmalloc_a(unsigned int sz, unsigned int *addr);
extern unsigned int pmalloc_addr, pmalloc_start;