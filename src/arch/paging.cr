require "./fastmem.cr"
require "./frame_allocator.cr"

lib PageStructs
  alias Page = UInt64

  struct PageTable
    pages : Page[512]
  end

  struct PageDirectory
    tables : UInt64[512]
  end

  struct PageDirectoryPointerTable
    dirs : UInt64[512]
  end

  struct PML4Table
    pdpt : UInt64[512]
  end

  fun kenable_paging(addr : PageStructs::PML4Table*)
  fun kdisable_paging
end

USERSPACE_START = 0x4000_0000u64
PTR_IDENTITY_MASK = 0xFFFF_8000_0000_0000u64

module Paging
  extend self

  # present, us, rw, global
  # PT_MASK_GLOBAL = 0x107
  # global mask, ps
  PT_MASK_GB_IDENTITY = 0x183
  # present, us, rw
  PT_MASK = 0x7

  @@usable_physical_memory = 0u64
  def usable_physical_memory
    @@usable_physical_memory
  end

  # identity-mapped virtual addresses of the page directory pointer table
  @@current_pdpt = Pointer(PageStructs::PageDirectoryPointerTable).null
  @@kernel_pdpt = Pointer(PageStructs::PageDirectoryPointerTable).null

  # linear address of the page directory pointer table
  def current_pdpt
    new_addr = @@current_pdpt.address & ~PTR_IDENTITY_MASK
    Pointer(PageStructs::PageDirectoryPointerTable).new(new_addr)
  end

  # set linear address of the page directory pointer table
  def current_pdpt=(x)
    new_addr = x.address | PTR_IDENTITY_MASK
    @@current_pdpt = Pointer(PageStructs::PageDirectoryPointerTable).new new_addr

    # update pml4 table
    pml4_addr = @@pml4_table.address | PTR_IDENTITY_MASK
    pml4_table = Pointer(PageStructs::PML4Table).new pml4_addr
    pml4_table.value.pdpt[0] = x.address | PT_MASK
  end

  @@pml4_table = Pointer(PageStructs::PML4Table).null

  def init_table(
    text_start : Void*, text_end : Void*,
    data_start : Void*, data_end : Void*,
    stack_start : Void*, stack_end : Void*,
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

    @@pml4_table = Pointer(PageStructs::PML4Table).pmalloc_a

    # allocate for the kernel's pdpt
    @@current_pdpt = Pointer(PageStructs::PageDirectoryPointerTable).pmalloc_a
    @@kernel_pdpt = @@current_pdpt
    @@pml4_table.value.pdpt[0] = @@kernel_pdpt.address | PT_MASK

    # identity map the physical memory on the higher half
    identity_map_pdpt = Pointer(PageStructs::PageDirectoryPointerTable).pmalloc_a
    dirs, _, _ = page_layer_indexes(@@usable_physical_memory)
    (dirs + 1).times do |i|
      pg = (i.to_u64 * 0x4000_0000u64) | PT_MASK_GB_IDENTITY
      identity_map_pdpt.value.dirs[i] = pg
    end
    @@pml4_table.value.pdpt[256] = identity_map_pdpt.address | PT_MASK

    # vga
    alloc_page_init false, false, 0xb8000

    # claim initial memory
    i = text_start.address
    while i <= text_end.address
      FrameAllocator.initial_claim(i)
      i += 0x1000
    end
    i = data_start.address
    while i <= data_end.address
      FrameAllocator.initial_claim(i)
      i += 0x1000
    end
    i = stack_start.address
    while i <= stack_end.address
      FrameAllocator.initial_claim(i)
      i += 0x1000
    end

    # text segment
    i = text_start.address
    while i < text_end.address
      alloc_frame false, false, i
      i += 0x1000
    end
    # data segment
    i = data_start.address
    while i < data_end.address
      alloc_frame true, false, i
      i += 0x1000
    end
    # stack segment
    i = stack_start.address
    while i < stack_end.address
      alloc_frame true, false, i
      i += 0x1000
    end
    # claim placement heap segment
    # we do this because the kernel's page table lies here:
    i = Pmalloc.start
    while i <= aligned(Pmalloc.addr)
      FrameAllocator.initial_claim(i)
      i += 0x1000
    end

    # update memory regions' inner pointers to identity mapped ones
    FrameAllocator.update_inner_pointers
    FrameAllocator.is_paging_setup = true
    new_addr = @@current_pdpt.address | PTR_IDENTITY_MASK
    @@current_pdpt = Pointer(PageStructs::PageDirectoryPointerTable).new new_addr
    @@kernel_pdpt = @@current_pdpt

    # enable paging
    flush
  end

  def aligned(x : USize) : USize
    t_addr(x) + 0x1000
  end

  private def page_layer_indexes(addr : USize)
    page_idx  = addr.unsafe_shr(12) & (0x200 - 1)
    table_idx = addr.unsafe_shr(21) & (0x200 - 1)
    dir_idx   = addr.unsafe_shr(30) & (0x200 - 1)
    Tuple.new(dir_idx.to_i32, table_idx.to_i32, page_idx.to_i32)
  end

  # state
  def flush
    asm("mov $0, %cr3" :: "r"(@@pml4_table) : "volatile", "memory")
  end

  # allocate page when pg is enabled
  # returns page address
  def alloc_page_pg(virt_addr_start : USize, rw : Bool, user : Bool, npages : USize = 1) : USize
    Idt.disable

    virt_addr = t_addr(virt_addr_start)
    virt_addr_end = virt_addr_start + npages * 0x1000

    # claim
    while virt_addr < virt_addr_end
      # allocate page frame
      dir_idx, table_idx, page_idx = page_layer_indexes(virt_addr)

      # directory
      if @@current_pdpt.value.dirs[dir_idx] == 0
        paddr = FrameAllocator.claim_with_addr | PT_MASK
        @@current_pdpt.value.dirs[dir_idx] = paddr
        pd = Pointer(PageStructs::PageDirectory).new(mt_addr paddr)
      else
        pd = Pointer(PageStructs::PageDirectory).new(mt_addr @@current_pdpt.value.dirs[dir_idx])
      end

      # table
      if pd.value.tables[table_idx] == 0
        paddr = FrameAllocator.claim_with_addr | PT_MASK
        pd.value.tables[table_idx] = paddr
        pt = Pointer(PageStructs::PageTable).new(mt_addr paddr)
      else
        pt = Pointer(PageStructs::PageTable).new(mt_addr pd.value.tables[table_idx])
      end

      # page
      phys_addr = FrameAllocator.claim_with_addr
      page = page_create(rw, user, phys_addr)
      pt.value.pages[page_idx] = page

      asm("invlpg ($0)" :: "r"(virt_addr) : "memory")
      virt_addr += 0x1000
    end

    Idt.enable
    #flush

    # return page
    virt_addr_start
  end

  def free_page_pg(virt_addr_start : USize, npages : USize = 1)
    panic "unimpl1"
    {% if false %}
    Idt.disable
    disable

    virt_addr_end = virt_addr_start + npages * 0x1000
    virt_addr = virt_addr_start

    while virt_addr < virt_addr_end
      address = free_page virt_addr
      idx = frame_index_for_address address
      declaim_frame idx
      virt_addr += 0x1000
    end

    enable
    Idt.enable
    {% end %}
  end

  # (de)allocate page directories for processes
  # NOTE: paging must be disabled for these to work
  def alloc_process_pdpt
    # claim frame for page directory
    pdpt = Pointer(PageStructs::PageDirectoryPointerTable).new(FrameAllocator.claim_with_addr)
    pdpt_phys = Pointer(PageStructs::PageDirectoryPointerTable).new(mt_addr pdpt.address)
    zero_page pdpt_phys.as(UInt8*)

    # copy lower kernel directory (first 1GB)
    # Serial.puts pdpt_phys, '\n'
    pdpt_phys.value.dirs[0] = @@kernel_pdpt.value.dirs[0]

    # return
    pdpt.address
  end

  def free_process_pdpt(pdtpa : USize)
    panic "unimpl2"
    {% if false %}
    Paging.disable

    pdpt = Pointer(PageStructs::PageDirectoryPointerTable).new(pdtpa.to_u64)
    # free directories
    i = 1
    while i < 4
      pd = Pointer(PageStructs::PageDirectory).new(pdpt.value.dirs[i] & 0xFFFF_F000)
      # free tables
      if !pd.null?
        512.times do |j|
          pta = pd.value.
        end
      end
      i += 1
    end

    # free itself
    FrameAllocator.declaim_addr(pdtpa.to_u64)

    Paging.enable
    {% end %}
  end

  # page creation
  private def page_create(rw : Bool, user : Bool, phys : UInt64) : UInt64
    page = 0x1u64
    if rw # second bit
      page |= 0x2u64
    end
    if user # third bit
      page |= 0x4u64
    end
    page |= t_addr(phys)
    page
  end

  # table address
  private def t_addr(addr : UInt64)
    addr & 0xFFFF_FFFF_FFFF_F000u64
  end

  # mapped table address
  private def mt_addr(addr : UInt64)
    (addr & 0xFFFF_FFFF_FFFF_F000u64) | PTR_IDENTITY_MASK
  end

  # identity map pages at init
  private def alloc_page_init(rw : Bool, user : Bool, addr : USize, virt_addr=0u64)
    if virt_addr == 0
      virt_addr = addr
    end
    dir_idx, table_idx, page_idx = page_layer_indexes(virt_addr)
    # Serial.puts Pointer(Void).new(addr.to_u64), dir_idx, ' ', table_idx, ' ', page_idx, '\n'

    # directory
    if @@current_pdpt.value.dirs[dir_idx] == 0
      pd = Pointer(PageStructs::PageDirectory).pmalloc_a
      paddr = pd.address | PT_MASK
      @@current_pdpt.value.dirs[dir_idx] = paddr
    else
      pd = Pointer(PageStructs::PageDirectory).new(t_addr @@current_pdpt.value.dirs[dir_idx])
    end

    # table
    if pd.value.tables[table_idx] == 0
      pt = Pointer(PageStructs::PageTable).pmalloc_a
      paddr = pt.address | PT_MASK
      pd.value.tables[table_idx] = paddr
    else
      pt = Pointer(PageStructs::PageTable).new(t_addr pd.value.tables[table_idx])
    end

    # page
    page = page_create(rw, user, addr)
    pt.value.pages[page_idx] = page
  end

  private def alloc_frame(rw : Bool, user : Bool, address : USize)
    FrameAllocator.initial_claim(address)
    alloc_page_init(rw, user, address)
  end
end
