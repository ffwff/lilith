require "./fastmem.cr"
require "./frame_allocator.cr"

module Paging
  extend self

  lib Data
    alias Page = UInt64

    struct PageTable
      pages : Page[512]
    end

    struct PageDirectory
      tables : UInt64[512]
    end

    struct PDPTable
      dirs : UInt64[512]
    end

    struct PML4Table
      pdpt : UInt64[512]
    end
  end

  IDENTITY_MASK    = 0xFFFF_8000_0000_0000u64
  KERNEL_OFFSET    = 0xFFFF_8080_0000_0000u64
  MAXIMUM_USER_PTR =        0x7F_FFFF_FFFFu64
  PDPT_SIZE        =        0x80_0000_0000u64

  KERNEL_PDPT_POINTER = 0xFFFF_8800_0000_0000u64
  KERNEL_PDPT_IDX     = page_layer_indexes(KERNEL_PDPT_POINTER)[0]
  BIG_ALLOCATOR_START = 0xFFFF_8810_0000_0000u64

  # present, us, rw, global
  # PT_MASK_GLOBAL = 0x107
  # nx, global, ps, 1gb
  PT_MASK_GB_IDENTITY = 0x8000000000000183
  # nx, global, ps
  PT_MASK_MB_IDENTITY_DIR = 0x8000000000000103
  # nx, global, ps, 2mb
  PT_MASK_MB_IDENTITY_TABLE = 0x8000000000000183
  # present, us, rw
  PT_MASK = 0x7

  @@usable_physical_memory = 0u64
  class_getter usable_physical_memory

  # Identity-mapped virtual address of the page directory pointer table for user processes
  @@current_pdpt = Pointer(Data::PDPTable).null
  # Identity-mapped virtual address of the page directory pointer table for kernel processes
  @@current_kernel_pdpt = Pointer(Data::PDPTable).null

  # Linear address of the page directory pointer table
  def current_pdpt
    new_addr = @@current_pdpt.address & ~Paging::IDENTITY_MASK
    Pointer(Data::PDPTable).new(new_addr)
  end

  # Lower-half page directory pointer table for kernel processes
  def real_pdpt
    pml4_addr = @@pml4_table.address | Paging::IDENTITY_MASK
    pml4_table = Pointer(Data::PML4Table).new pml4_addr
    new_addr = pml4_table.value.pdpt[0] & ~Paging::IDENTITY_MASK
    Pointer(Data::PDPTable).new(new_addr)
  end

  # Linear address of the page directory pointer table
  def current_kernel_pdpt
    new_addr = @@current_kernel_pdpt.address & ~Paging::IDENTITY_MASK
    Pointer(Data::PDPTable).new(new_addr)
  end

  # Maps user page directory pointer table.
  #
  # NOTE: this must be NoInline because in changes the address space
  # in a way that the compiler doesn't recognize.
  @[NoInline]
  def current_pdpt=(x)
    if x.null?
      @@current_pdpt = Pointer(Data::PDPTable).null
      pml4_addr = @@pml4_table.address | Paging::IDENTITY_MASK
      pml4_table = Pointer(Data::PML4Table).new pml4_addr
      pml4_table.value.pdpt[0] = 0u64
      return
    end

    new_addr = x.address | Paging::IDENTITY_MASK
    @@current_pdpt = Pointer(Data::PDPTable).new new_addr

    # update pml4 table
    pml4_addr = @@pml4_table.address | Paging::IDENTITY_MASK
    pml4_table = Pointer(Data::PML4Table).new pml4_addr
    pml4_table.value.pdpt[0] = x.address | PT_MASK
  end

  # Maps kernel page directory pointer table.
  #
  # NOTE: this must be NoInline because in changes the address space
  # in a way that the compiler doesn't recognize.
  @[NoInline]
  def current_kernel_pdpt=(x)
    new_addr = x.address | Paging::IDENTITY_MASK
    @@current_kernel_pdpt = Pointer(Data::PDPTable).new new_addr

    # update pml4 table
    pml4_addr = @@pml4_table.address | Paging::IDENTITY_MASK
    pml4_table = Pointer(Data::PML4Table).new pml4_addr
    pml4_table.value.pdpt[KERNEL_PDPT_IDX] = x.address | PT_MASK
  end

  @@pml4_table = Pointer(Data::PML4Table).null

  # Initializes table from bootstrap code.
  def init_table(
    text_start : Void*, text_end : Void*,
    data_start : Void*, data_end : Void*,
    stack_start : Void*, stack_end : Void*,
    int_stack_start : Void*, int_stack_end : Void*,
    mboot_header : Multiboot::MultibootInfo*
  )
    cur_mmap_addr = mboot_header.value.mmap_addr
    mmap_end_addr = cur_mmap_addr + mboot_header.value.mmap_length

    while cur_mmap_addr < mmap_end_addr
      cur_entry = Pointer(Multiboot::MemoryMapTable).new(cur_mmap_addr.to_u64)

      if cur_entry.value.base_addr != 0 && cur_entry.value.type == MULTIBOOT_MEMORY_AVAILABLE
        entry = cur_entry.value
        FrameAllocator.add_region entry.base_addr, entry.length
        @@usable_physical_memory += entry.length
      end

      cur_mmap_addr += cur_entry[0].size + sizeof(UInt32)
    end

    @@pml4_table = PermaAllocator.malloca_t(Data::PML4Table)

    # allocate for the kernel's pdpt
    @@current_pdpt = PermaAllocator.malloca_t(Data::PDPTable)
    # store it at the kernel offset
    @@pml4_table.value.pdpt[257] = @@current_pdpt.address | PT_MASK

    # identity map the physical memory on the higher half
    if X86::CPUID.has_feature?(X86::CPUID::FeaturesExtendedEdx::PDPE1GB)
      # 1 GiB paging
      identity_map_pdpt = PermaAllocator.malloca_t(Data::PDPTable)
      _, dirs, _, _ = page_layer_indexes(@@usable_physical_memory)
      (dirs + 1).times do |i|
        pg = (i.to_u64 * 0x4000_0000u64) | PT_MASK_GB_IDENTITY
        identity_map_pdpt.value.dirs[i] = pg
      end
      @@pml4_table.value.pdpt[256] = identity_map_pdpt.address | PT_MASK
    else
      # 2 MiB paging
      identity_map_pdpt = PermaAllocator.malloca_t(Data::PDPTable)
      _, dirs, tables, _ = page_layer_indexes(@@usable_physical_memory)
      # add remaining tables to directory count
      if tables > 0
        dirs += 1
      end
      # directories
      dirs.times do |i|
        identity_dir = PermaAllocator.malloca_t(Data::PageDirectory)
        512.times do |j|
          identity_dir_phys = i.to_u64 * 0x4000_0000u64 + j.to_u64 * 0x20_0000u64
          identity_dir.value.tables[j] = identity_dir_phys | PT_MASK_MB_IDENTITY_TABLE
        end
        identity_map_pdpt.value.dirs[i] = identity_dir.address | PT_MASK_MB_IDENTITY_DIR
      end
      @@pml4_table.value.pdpt[256] = identity_map_pdpt.address | PT_MASK
    end

    # claim initial memory
    i = text_start.address
    while i <= text_end.address
      FrameAllocator.initial_claim(i - Paging::KERNEL_OFFSET)
      i += 0x1000
    end
    i = data_start.address
    while i <= data_end.address
      FrameAllocator.initial_claim(i - Paging::KERNEL_OFFSET)
      i += 0x1000
    end
    i = stack_start.address
    while i <= stack_end.address
      FrameAllocator.initial_claim(i - Paging::KERNEL_OFFSET)
      i += 0x1000
    end
    i = int_stack_start.address
    while i <= int_stack_end.address
      FrameAllocator.initial_claim(i - Paging::KERNEL_OFFSET)
      i += 0x1000
    end

    # text segment
    i = text_start.address
    while i < text_end.address
      alloc_frame_init false, false, i, execute: true
      i += 0x1000
    end
    # data segment
    i = data_start.address
    while i < data_end.address
      alloc_frame_init true, false, i
      i += 0x1000
    end
    # stack segment
    i = stack_start.address
    while i < stack_end.address
      alloc_frame_init true, false, i
      i += 0x1000
    end
    # stack segment
    i = int_stack_start.address
    while i < int_stack_end.address
      alloc_frame_init true, false, i
      i += 0x1000
    end
    # claim placement heap segment
    # we do this because the kernel's page table lies here:
    i = PermaAllocator.start
    while i <= aligned(PermaAllocator.addr)
      FrameAllocator.initial_claim(i)
      i += 0x1000
    end

    # update memory regions' inner pointers to identity mapped ones
    FrameAllocator.update_inner_pointers
    FrameAllocator.is_paging_setup = true
    new_addr = @@current_pdpt.address | Paging::IDENTITY_MASK
    @@current_pdpt = Pointer(Data::PDPTable).new new_addr

    # enable paging
    flush
  end

  # Calculate page table indexes from a virtual address.
  def page_layer_indexes(addr : UInt64)
    pdpt_idx = (addr >> 39) & (0x200 - 1)
    dir_idx = (addr >> 30) & (0x200 - 1)
    table_idx = (addr >> 21) & (0x200 - 1)
    page_idx = (addr >> 12) & (0x200 - 1)
    {pdpt_idx.to_i32, dir_idx.to_i32, table_idx.to_i32, page_idx.to_i32}
  end

  # Flushes the page
  #
  # NOTE: this must be NoInline because in changes the address space
  # in a way that the compiler doesn't recognize. 
  @[NoInline]
  def flush
    asm("mov $0, %cr3" :: "r"(@@pml4_table) : "volatile", "memory")
  end

  # Allocates a page after bootstrapping has been completed.
  def alloc_page(virt_addr_start : UInt64, rw : Bool, user : Bool,
                 npages : USize = 1, phys_addr_start : UInt64 = 0,
                 execute = false) : UInt64
    # Serial.print "allocate: ", Pointer(Void).new(virt_addr_start), ' ', npages, '\n'
    Idt.disable

    virt_addr = aligned_floor(virt_addr_start)
    virt_addr_end = virt_addr_start + npages * 0x1000

    pml4_table = Pointer(Data::PML4Table).new(mt_addr @@pml4_table.address)

    # claim
    while virt_addr < virt_addr_end
      abort "allocating user page inside non-user area!" if user && virt_addr > Paging::MAXIMUM_USER_PTR

      # allocate page frame
      pdpt_idx, dir_idx, table_idx, page_idx = page_layer_indexes(virt_addr)

      if pml4_table.value.pdpt[pdpt_idx] == 0
        paddr = FrameAllocator.claim_with_addr | PT_MASK
        pml4_table.value.pdpt[pdpt_idx] = paddr
        pdpt = Pointer(Data::PDPTable).new(mt_addr paddr)
        zero_page pdpt.as(UInt8*)
      else
        pdpt = Pointer(Data::PDPTable)
          .new(mt_addr pml4_table.value.pdpt[pdpt_idx])
      end

      # directory
      if pdpt.value.dirs[dir_idx] == 0
        paddr = FrameAllocator.claim_with_addr | PT_MASK
        pdpt.value.dirs[dir_idx] = paddr
        pd = Pointer(Data::PageDirectory).new(mt_addr paddr)
        zero_page pd.as(UInt8*)
      else
        pd = Pointer(Data::PageDirectory).new(mt_addr pdpt.value.dirs[dir_idx])
      end

      # table
      if pd.value.tables[table_idx] == 0
        paddr = FrameAllocator.claim_with_addr | PT_MASK
        pd.value.tables[table_idx] = paddr
        pt = Pointer(Data::PageTable).new(mt_addr paddr)
        zero_page pt.as(UInt8*)
      else
        pt = Pointer(Data::PageTable).new(mt_addr pd.value.tables[table_idx])
      end

      # page
      if phys_addr_start != 0
        phys_addr = phys_addr_start
        phys_addr_start += 0x1000
      else
        phys_addr = FrameAllocator.claim_with_addr
      end
      abort "page must be zero" if pt.value.pages[page_idx] != 0
      page = page_create(rw, user, phys_addr, execute)
      pt.value.pages[page_idx] = page

      asm("invlpg ($0)" :: "r"(virt_addr) : "memory")
      virt_addr += 0x1000
    end

    Idt.enable

    # return page
    virt_addr_start
  end

  # Allocates a page from a kernel thread.
  @[NoInline]
  def alloc_page_drv(virt_addr_start : UInt64, rw : Bool, user : Bool,
                        npages : USize = 1,
                        execute : Bool = false) : UInt64
    retval = 0u64
    asm("syscall"
            : "={rax}"(retval)
            : "{rax}"(SC_MMAP_DRV),
              "{rbx}"(virt_addr_start),
              "{rdx}"(rw),
              "{r8}"(user),
              "{r9}"(npages),
              "{r10}"(execute)
            : "cc", "memory", "volatile", "rcx", "r11", "r12", "rdi", "rsi")
    retval
  end

  # Removes a virtual address from memory.
  def remove_page(virt_addr : UInt64)
    pdpt_idx, dir_idx, table_idx, page_idx = page_layer_indexes(virt_addr)

    pml4_table = Pointer(Data::PML4Table).new(mt_addr @@pml4_table.address)

    return false if pml4_table.value.pdpt[pdpt_idx] == 0u64
    pdpt = Pointer(Data::PDPTable)
      .new(mt_addr pml4_table.value.pdpt[pdpt_idx])

    return false if pdpt.value.dirs[dir_idx] == 0u64
    pd = Pointer(Data::PageDirectory).new(mt_addr pdpt.value.dirs[dir_idx])

    return false if pd.value.tables[table_idx] == 0u64
    pt = Pointer(Data::PageTable).new(mt_addr pd.value.tables[table_idx])

    pt.value.pages[page_idx] = 0u64
    asm("invlpg ($0)" :: "r"(virt_addr) : "memory")

    true
  end

  # Allocate page directory pointer table for a process
  def alloc_process_pdpt
    # claim frame for page directory
    pdpt = Pointer(Data::PDPTable).new(FrameAllocator.claim_with_addr)
    pdpt_phys = Pointer(Data::PDPTable).new(mt_addr pdpt.address)
    zero_page pdpt_phys.as(UInt8*)

    # return
    pdpt.address
  end

  # Deallocate page directory pointer table and containing pages for a process
  def free_process_pdpt(pdtpa : UInt64, free_pdpta? : Bool = true)
    pdpt = Pointer(Data::PDPTable).new(mt_addr pdtpa)
    # Serial.print "pdpt: ", pdpt, '\n'
    # free directories
    512.times do |i|
      pd_addr = t_addr(pdpt.value.dirs[i])
      # free tables
      if pd_addr != 0
        pd = Pointer(Data::PageDirectory).new(mt_addr pd_addr)
        # Serial.print "pd: ", pd, '\n'
        512.times do |j|
          pt_addr = t_addr(pd.value.tables[j])
          if pt_addr != 0
            pt = Pointer(Data::PageTable).new(mt_addr pt_addr)
            # Serial.print "pt: ", Pointer(Void).new(pt_addr), '\n'
            512.times do |k|
              page_phys = t_addr(pt.value.pages[k])
              if page_phys != 0
                # Serial.print "page: ", Pointer(Void).new(page_phys), '\n'
                FrameAllocator.declaim_addr page_phys
              end
            end
            FrameAllocator.declaim_addr pt_addr
          end
        end
        FrameAllocator.declaim_addr pd_addr
      end
    end

    # free itself
    if free_pdpta?
      FrameAllocator.declaim_addr pdtpa
    end
  end

  PG_WRITE_BIT = 1u64 << 1u64
  PG_USER_BIT  = 1u64 << 2u64
  NX_BIT       = 1u64 << 63u64

  # Creates a page
  private def page_create(rw : Bool, user : Bool, phys : UInt64,
                          execute : Bool) : UInt64
    page = 0x1u64
    page |= aligned_floor(phys)
    if rw
      page |= PG_WRITE_BIT
    end
    if user
      page |= PG_USER_BIT
    end
    unless execute
      page = page.to_u64 | NX_BIT
    end
    page
  end

  # Page-align an address to an address higher than it.
  def aligned(x : UInt64) : UInt64
    aligned_floor(x) + 0x1000
  end

  # Page-align an address to an address equal or lower than it.
  def aligned_floor(addr : UInt64)
    addr & 0xFFFF_FFFF_FFFF_F000u64
  end

  # Table address
  def t_addr(addr : UInt64)
    addr & 0xFFFF_FFFF_F000u64
  end

  # Mapped table address
  def mt_addr(addr : UInt64)
    t_addr(addr) | Paging::IDENTITY_MASK
  end

  # identity map pages at init
  private def alloc_page_init(rw : Bool, user : Bool, addr : UInt64, virt_addr : UInt64, execute = false)
    if virt_addr == 0
      virt_addr = addr
    end
    # since we're only in the init stage, the pdpt table is not gonna change
    _, dir_idx, table_idx, page_idx = page_layer_indexes(virt_addr)

    # directory
    if @@current_pdpt.value.dirs[dir_idx] == 0
      pd = PermaAllocator.malloca_t(Data::PageDirectory)
      paddr = pd.address | PT_MASK
      @@current_pdpt.value.dirs[dir_idx] = paddr
    else
      pd = Pointer(Data::PageDirectory).new(aligned_floor @@current_pdpt.value.dirs[dir_idx])
    end

    # table
    if pd.value.tables[table_idx] == 0
      pt = PermaAllocator.malloca_t(Data::PageTable)
      paddr = pt.address | PT_MASK
      pd.value.tables[table_idx] = paddr
    else
      pt = Pointer(Data::PageTable).new(aligned_floor pd.value.tables[table_idx])
    end

    # page
    page = page_create(rw, user, addr, execute)
    pt.value.pages[page_idx] = page
  end

  private def alloc_frame_init(rw : Bool, user : Bool, virt_addr : UInt64, execute = false)
    phys_addr = virt_addr - Paging::KERNEL_OFFSET
    alloc_page_init(rw, user, phys_addr, virt_addr, execute: execute)
  end

  # Checks if a page in the current address exists.
  def check_user_addr(ptr : Void*)
    # FIXME: check for kernel/unmapped pages
    pdpt_idx, dir_idx, table_idx, page_idx = page_layer_indexes(ptr.address)

    pml4_table = Pointer(Data::PML4Table).new(mt_addr @@pml4_table.address)

    return false if pml4_table.value.pdpt[pdpt_idx] == 0u64
    pdpt = Pointer(Data::PDPTable)
      .new(mt_addr pml4_table.value.pdpt[pdpt_idx])

    return false if pdpt.value.dirs[dir_idx] == 0u64
    pd = Pointer(Data::PageDirectory).new(mt_addr pdpt.value.dirs[dir_idx])

    return false if pd.value.tables[table_idx] == 0u64
    pt = Pointer(Data::PageTable).new(mt_addr pd.value.tables[table_idx])

    pt.value.pages[page_idx] != 0
  end

  # Translates a virtual address to physical address
  def virt_to_phys_address(ptr : Void*)
    pdpt_idx, dir_idx, table_idx, page_idx = page_layer_indexes(ptr.address)
    offset = ptr.address & 0xFFF

    pml4_table = Pointer(Data::PML4Table).new(mt_addr @@pml4_table.address)

    return 0u64 if pml4_table.value.pdpt[pdpt_idx] == 0u64
    pdpt = Pointer(Data::PDPTable)
      .new(mt_addr pml4_table.value.pdpt[pdpt_idx])

    return 0u64 if pdpt.value.dirs[dir_idx] == 0u64
    pd = Pointer(Data::PageDirectory).new(mt_addr pdpt.value.dirs[dir_idx])

    return 0u64 if pd.value.tables[table_idx] == 0u64
    pt = Pointer(Data::PageTable).new(mt_addr pd.value.tables[table_idx])

    aligned_floor(pt.value.pages[page_idx]) + offset
  end
end
