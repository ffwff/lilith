#include "arch/mem.h"
#include "arch/pmalloc.h"
#include "stdint.h"

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

struct page_table {
    struct page pages[1024];  // 1024*4kb = 4MB
};

struct page_directory {
    struct page_table *tables[1024];
    uint32_t tables_physical[1024];
};

struct page_directory *kernel_page_dir = 0;

// impl
void kalloc_page(int rw, int user, uint32_t address) {
    uint32_t phys = address;
    address /= 0x1000;
    uint32_t table_idx = address / 1024;
    if (kernel_page_dir->tables[table_idx] == 0) {
        uint32_t ptr;
        kernel_page_dir->tables[table_idx] = pmalloc_a(sizeof(struct page_table), &ptr);
        kernel_page_dir->tables_physical[table_idx] = (uint32_t)ptr | 0x7;
    }
    kernel_page_dir->tables[table_idx]->pages[address % 1024] = page_create(rw, user, (phys & 0xFFFFF000) >> 8);
}

void kalloc_page_mapping(int rw, int user, uint32_t virt, uint32_t phys) {
    virt /= 0x1000;
    uint32_t table_idx = virt / 1024;
    kernel_page_dir->tables[table_idx]->pages[virt % 1024] = page_create(rw, user, (phys & 0xFFFFF000) >> 8);
}

void kinit_paging() {
    kernel_page_dir = pmalloc_a(sizeof(struct page_directory), 0);
    memset(kernel_page_dir, 0, sizeof(struct page_directory));
}

int kpage_present(uint32_t address) {
    address /= 0x1000;
    uint32_t table_idx = address / 1024;
    if (kernel_page_dir->tables[table_idx] == 0) {
        return 0;
    }
    return kernel_page_dir->tables[table_idx]->pages[address % 1024].present;
}

int kpage_table_present(uint32_t table_idx) {
    if (kernel_page_dir->tables[table_idx] == 0) {
        return 0;
    }
    return 1;
}

void kpage_dir_set_table(uint32_t table_idx, uint32_t address) {
    kernel_page_dir->tables[table_idx] = (struct page_table*)address;
    kernel_page_dir->tables_physical[table_idx] = address | 0x7;
}

// paging control
void kenable_paging() {
    asm volatile("mov %0, %%cr3" ::"r"((uint32_t)kernel_page_dir->tables_physical));
    uint32_t cr0;
    asm volatile("mov %%cr0, %0"
                 : "=r"(cr0));
    cr0 |= 0x80000000;  // Enable paging!
    asm volatile("mov %0, %%cr0" ::"r"(cr0));
}

void kdisable_paging() {
    uint32_t cr0;
    asm volatile("mov %%cr0, %0"
                 : "=r"(cr0));
    cr0 &= ~(1 << 31);  // clear PG bit
    asm volatile("mov %0, %%cr0" ::"r"(cr0));
}