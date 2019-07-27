# NOTE: we only do identity paging

lib PageStructs
  alias Page = UInt32

  struct PageTable
    pages : Page[1024]
  end

  struct PageDirectory
    tables : UInt32[1024]
  end

  fun kenable_paging(addr : UInt32)
  fun kdisable_paging
end

module Paging
  extend self

  # NOTE: paging module should not be used after
  # it is set up, any memory allocated in the pmalloc
  # functions is unmapped
  @@frame_base_addr : UInt32 = 0
  @@frame_length : UInt32 = 0
  @@frames = PBitArray.null
  @@frames_search_from : Int32 = 0

  def usable_physical_memory
    @@frame_length
  end

  @@current_page_dir = Pointer(PageStructs::PageDirectory).null

  def current_page_dir
    @@current_page_dir
  end

  def current_page_dir=(@@current_page_dir); end

  @@kernel_page_dir = Pointer(PageStructs::PageDirectory).null

  def init_table(
    text_start : Void*, text_end : Void*,
    data_start : Void*, data_end : Void*,
    stack_end : Void*, stack_start : Void*,
    mboot_header : Multiboot::MultibootInfo*
  )
    cur_mmap_addr = mboot_header[0].mmap_addr
    mmap_end_addr = cur_mmap_addr + mboot_header[0].mmap_length

    while cur_mmap_addr < mmap_end_addr
      cur_entry = Pointer(Multiboot::MemoryMapTable).new(cur_mmap_addr.to_u64)

      if cur_entry[0].base_addr != 0 && cur_entry[0].type == MULTIBOOT_MEMORY_AVAILABLE
        entry = cur_entry[0]
        @@frame_base_addr = entry.base_addr.to_u32
        @@frame_length = entry.length.to_u32
        break
      end

      cur_mmap_addr += cur_entry[0].size + sizeof(UInt32)
    end

    panic "can't find page frames" if @@frame_length == 0
    nframes = @@frame_length.to_i32.unsafe_div 0x1000
    @@frames = PBitArray.new nframes
    Serial.puts "page: ", pointerof(@@frames), '\n'

    @@current_page_dir = Pointer(PageStructs::PageDirectory).pmalloc_a
    @@kernel_page_dir = @@current_page_dir

    # vga
    alloc_page_init true, false, 0xb8000

    # text segment
    i = text_start.address.to_u32
    while i < text_end.address.to_u32
      alloc_frame false, false, i
      i += 0x1000
    end
    # data segment
    i = data_start.address.to_u32
    while i < data_end.address.to_u32
      alloc_frame true, false, i
      i += 0x1000
    end
    # stack segment
    i = stack_start.address.to_u32
    while i < stack_end.address.to_u32
      alloc_frame true, false, i
      i += 0x1000
    end
    # claim placement heap segment
    # we do this because the kernel's page table lies here:
    i = PMALLOC_STATE.start.to_u32
    while i <= aligned(PMALLOC_STATE.addr)
      @@frames[frame_index_for_address i] = true
      i += 0x1000
    end
    # -- switch page directory
    enable
  end

  def aligned(x : UInt32) : UInt32
    (x & 0xFFFF_F000) + 0x1000
  end

  # state
  @[AlwaysInline]
  def enable
    addr = @@current_page_dir.address.to_u32
    PageStructs.kenable_paging(addr)
  end

  @[AlwaysInline]
  def disable
    PageStructs.kdisable_paging
  end

  # allocate page when pg is enabled
  # returns page address
  def alloc_page_pg(virt_addr_start : UInt32, rw : Bool, user : Bool, npages : UInt32 = 1) : UInt32
    Idt.disable
    disable

    virt_addr = virt_addr_start & 0xFFFF_F000
    virt_addr_end = virt_addr_start + npages * 0x1000

    # claim
    while virt_addr < virt_addr_end
      # Serial.puts "virt addr: ", Pointer(Void).new(virt_addr.to_u64), "\n"
      # allocate page frame
      iaddr = claim_frame
      addr = iaddr.to_u32 * 0x1000 + @@frame_base_addr

      # create new page
      page_addr = virt_addr.unsafe_div 0x1000
      table_idx = page_addr.unsafe_div 1024
      if @@current_page_dir.value.tables[table_idx] == 0
        # page table isn't present
        # claim a page for storing the page table
        pt_iaddr = claim_frame
        pt_addr = pt_iaddr.to_u32 * 0x1000 + @@frame_base_addr
        memset Pointer(UInt8).new(pt_addr.to_u64), 0, 4096
        @@current_page_dir.value.tables[table_idx] = pt_addr | 0x7
      end
      alloc_page(rw, user, virt_addr, addr)

      virt_addr += 0x1000
    end

    enable
    Idt.enable

    # return page
    virt_addr_start
  end

  def free_page_pg(virt_addr_start : UInt32, npages : UInt32 = 1)
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
  end

  # allocate page directories for processes
  # NOTE: paging must be disabled for these to work
  def alloc_process_page_dir
    # claim frame for page directory
    iaddr = claim_frame
    pd_addr = iaddr.to_u32 * 0x1000 + @@frame_base_addr
    pd = Pointer(PageStructs::PageDirectory).new(pd_addr.to_u64)
    memset Pointer(UInt8).new(pd_addr.to_u64), 0, 4096

    # copy lower half (kernel half)
    512.times do |i|
      pd.value.tables[i] = @@kernel_page_dir.value.tables[i]
    end

    # return
    pd.address
  end

  def free_process_page_dir(pda : UInt32)
    Paging.disable

    pd = Pointer(PageStructs::PageDirectory).new(pda.to_u64)
    # free the higher half
    i = 512
    while i < 1024
      pta = pd.value.tables[i] & 0xFFFF_F000
      pt = Pointer(PageStructs::PageTable).new(pta.to_u64)
      # free tables
      if pta != 0
        j = 0
        while j < 1024
          if pt.value.pages[j] != 0
            frame = pt.value.pages[j] & 0xFFFF_F000
            declaim_frame(frame_index_for_address(frame))
          end
          j += 1
        end
        declaim_frame(frame_index_for_address(pta))
      end
      i += 1
    end

    # free itself
    declaim_frame(frame_index_for_address(pda))

    Paging.enable
  end

  # frame alloc
  @[AlwaysInline]
  private def frame_index_for_address(address : UInt32) : Int32
    (address - @@frame_base_addr).unsafe_div(0x1000).to_i32
  end

  private def claim_frame
    idx, iaddr = @@frames.first_unset_from @@frames_search_from
    @@frames_search_from = max idx, @@frames_search_from
    panic "no more physical memory!" if iaddr == -1
    @@frames[iaddr] = true
    iaddr
  end

  private def declaim_frame(idx)
    @@frames_search_from = min idx, @@frames_search_from
    @@frames[idx] = false
  end

  # page creation
  private def page_create(rw : Bool, user : Bool, phys : UInt32) : UInt32
    page = 0x1u32
    if rw # second bit
      page |= 0x2u32
    end
    if user # third bit
      page |= 0x4u32
    end
    page |= phys & 0xFFFF_F000
    page
  end

  # page alloc at init
  private def alloc_page_init(rw : Bool, user : Bool, address : UInt32)
    phys = address
    address = address.unsafe_div(0x1000)
    table_idx = address.unsafe_div(1024).to_i32
    if @@current_page_dir.value.tables[table_idx] == 0
      ptr = Pointer(PageStructs::PageTable).pmalloc_a
      @@current_page_dir.value.tables[table_idx] = ptr.address.to_u32 | 0x7
    else
      ptr = Pointer(PageStructs::PageTable).new((@@current_page_dir.value.tables[table_idx] & 0xFFFF_F000).to_u64)
    end
    page = page_create(rw, user, phys)
    ptr.value.pages[address.unsafe_mod 1024] = page
  end

  private def alloc_frame(rw : Bool, user : Bool, address : UInt32)
    idx = frame_index_for_address address
    panic "already allocated" if @@frames[idx]
    @@frames[idx] = true
    alloc_page_init(rw, user, address)
  end

  # page alloc at runtime
  private def alloc_page(rw : Bool, user : Bool, address : UInt32, phys : UInt32)
    address = address.unsafe_div(0x1000)
    table_idx = address.unsafe_div(1024).to_i32
    page = page_create(rw, user, phys)
    panic "no table for page" if @@current_page_dir.value.tables[table_idx] == 0
    ptr = Pointer(PageStructs::PageTable).new((@@current_page_dir.value.tables[table_idx] & 0xFFFF_F000).to_u64)
    ptr.value.pages[address.unsafe_mod 1024] = page
  end

  private def free_page(address : UInt32)
    address = address.unsafe_div(0x1000)
    table_idx = address.unsafe_div(1024).to_i32
    panic "no table for page" if @@current_page_dir.value.tables[table_idx].null?
    @@current_page_dir.value.tables[table_idx].value.pages[address.unsafe_mod 1024] = 0
  end
end
