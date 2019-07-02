#include "mem/mem.h"
#include "mem/pmalloc.h"
#include "stdint.h"

// NOTE: we only do identity paging

// paging control
static void enable_paging() {
    uint32_t cr0;
    asm volatile("mov %%cr0, %0"
                 : "=r"(cr0));
    cr0 |= 0x80000000;  // Enable paging!
    asm volatile("mov %0, %%cr0" ::"r"(cr0));
}

static void disable_paging() {
    uint32_t cr0;
    asm volatile("mov %%cr0, %0"
                 : "=r"(cr0));
    cr0 &= ~(1 << 31);  // clear PG bit
    asm volatile("mov %0, %%cr0" ::"r"(cr0));
}

//
struct page {
    uint32_t present : 1;
    uint32_t rw : 1;
    uint32_t user : 1;
    uint32_t accessed : 1;
    uint32_t dirty : 1;
    uint32_t unused : 7;
    uint32_t frame : 20;
};

static struct page page_create(int rw, int user, uint32_t phys_addr) {
    struct page page = {0};
    page.present = 1;
    page.rw = rw;
    page.user = user;
    page.accessed = 0;
    page.dirty = 0;
    page.unused = 0;
    page.frame = phys_addr >> 4;
    return page;
}

//
struct page_table {
    struct page pages[1024];  // 1024*4kb = 4MB
};

//
struct page_directory {
    struct page_table *tables[1024];
    uint32_t tables_physical[1024];
};

static void alloc_page(struct page_directory *dir, int rw, int user, uint32_t address) {
    uint32_t phys = address;
    address /= 0x1000;
    uint32_t table_idx = address / 1024;
    if (dir->tables[table_idx] == 0) {
        uint32_t ptr;
        dir->tables[table_idx] = pmalloc_a(sizeof(struct page_table), &ptr);
        dir->tables_physical[table_idx] = (uint32_t)ptr | 0x7;
    }
    dir->tables[table_idx]->pages[address % 1024] = page_create(rw, user, (phys & 0xFFFFF000) >> 8);
}

#define ALIGNED(x) ((((uint32_t)x)&0xFFFFF000)+0x1000)

struct page_directory *kernel_dir;
void kinit_paging(void *text_start, void *text_end,
                void *data_start, void *data_end,
                void *stack_start, void *stack_end) {
    kernel_dir = pmalloc_a(sizeof(struct page_directory), 0);
    memset(kernel_dir, 0, sizeof(struct page_directory));
    alloc_page(kernel_dir, 0, 0, 0xb8000); // VGA
    for (uint32_t i = (uint32_t)text_start; i <= ALIGNED(text_end); i += 0x1000) {
        alloc_page(kernel_dir, 0, 0, i);
    }
    for (uint32_t i = (uint32_t)data_start; i <= ALIGNED(data_end); i += 0x1000) {
        alloc_page(kernel_dir, 1, 0, i);
    }
    for (uint32_t i = (uint32_t)stack_start; i <= ALIGNED(stack_end); i += 0x1000) {
        alloc_page(kernel_dir, 1, 0, i);
    }
    for (uint32_t i = pmalloc_start; i < pmalloc_addr; i += 0x1000) {
        alloc_page(kernel_dir, 1, 1, i);
    }
    // switch page directory
    asm volatile("mov %0, %%cr3" ::"r"((uint32_t)kernel_dir->tables_physical));
    enable_paging();
}
