lib ElfStructs
  # http://www.skyfree.org/linux/references/ELF_Format.pdf
  # https://0x00sec.org/t/dissecting-and-exploiting-elf-files/7267

  @[Packed]
  struct Elf32Header
    e_type : Elf32EType
    e_machine : UInt16
    e_version : UInt32
    e_entry : UInt32
    e_phoff : UInt32
    e_shoff : UInt32
    e_flags : UInt32
    e_ehsize : UInt16
    e_phentsize : UInt16
    e_phnum : UInt16
    e_shentsize : UInt16
    e_shnum : UInt16
    e_shstrndx : UInt16
  end

  @[Packed]
  struct Elf64Header
    e_type : Elf32EType
    e_machine : UInt16
    e_version : UInt32
    e_entry : UInt64
    e_phoff : UInt64
    e_shoff : UInt64
    e_flags : UInt32
    e_ehsize : UInt16
    e_phentsize : UInt16
    e_phnum : UInt16
    e_shentsize : UInt16
    e_shnum : UInt16
    e_shstrndx : UInt16
  end

  enum Elf32EType : UInt16
    ET_NONE = 0
    ET_REL  = 1
    ET_EXEC = 2
    ET_DYN  = 3
    ET_CORE = 4
  end

  @[Packed]
  struct Elf32ProgramHeader
    p_type : Elf32PType
    p_offset : UInt32
    p_vaddr : UInt32
    p_paddr : UInt32
    p_filesz : UInt32
    p_memsz : UInt32
    p_flags : Elf32PFlags
    p_align : UInt32
  end

  @[Packed]
  struct Elf64ProgramHeader
    p_type : Elf32PType
    p_flags : Elf32PFlags
    p_offset : UInt64
    p_vaddr : UInt64
    p_paddr : UInt64
    p_filesz : UInt64
    p_memsz : UInt64
    p_align : UInt64
  end

  enum Elf32PType : UInt32
    NULL_TYPE    =          0
    LOAD         =          1
    DYNAMIC      =          2
    INTERP       =          3
    NOTE         =          4
    SHLIB        =          5
    PHDR         =          6
    TLS          =          7
    GNU_EH_FRAME = 1685382480
    GNU_STACK    = 1685382481
    GNU_RELRO    = 1685382482
    PAX_FLAGS    = 1694766464
    HIOS         = 1879048191
    ARM_EXIDX    = 1879048193
  end

  @[Flags]
  enum Elf32PFlags : UInt32
    PF_X = 0x1
    PF_W = 0x2
    PF_R = 0x4
  end

  @[Packed]
  struct Elf32SectionHeader
    sh_name : UInt32
    sh_type : Elf32PType
    sh_flags : UInt32
    sh_addr : UInt32
    sh_offset : UInt32
    sh_size : UInt32
    sh_link : UInt32
    sh_info : UInt32
    sh_addralign : UInt32
    sh_entsize : UInt32
  end
end

module ElfReader
  extend self

  EI_MAG0       = 0
  EI_MAG1       = 1
  EI_MAG2       = 2
  EI_MAG3       = 3
  EI_CLASS      = 4 # Architecture (32/64)
  EI_DATA       = 5 # Byte Order
  EI_VERSION    = 6 # ELF Version
  EI_OSABI      = 7 # OS Specific
  EI_ABIVERSION = 8 # OS Specific
  EI_PAD        = 9 # Padding

  ELFCLASS32 = 1
  ELFCLASS64 = 2

  ELF_EIDENT_SZ = 16

  private enum ParserState
    Start
    Byte
    ElfHeader
    ElfHeader64
    ProgramHeader
    ProgramHeader64
    SegmentHeader
  end

  enum ParserError
    EmptyFile
    InvalidElfHdr
    InvalidProgramHdrSz
    ExpectedProgramHdr
  end

  struct ElfHeader
    getter is64, e_phnum, e_shnum, e_entry

    def initialize(@is64 : Bool,
                   @e_phnum : UInt16,
                   @e_shnum : UInt16,
                   @e_entry : USize)
    end
  end

  struct MemMapHeader
    getter file_offset, filesz, vaddr, memsz, attrs

    def initialize(@file_offset : USize,
                   @filesz : USize,
                   @vaddr : USize,
                   @memsz : USize, @attrs : MemMapNode::Attributes)
    end
  end

  struct Result
    getter is64, initial_ip, heap_start, mmap_list

    def initialize(@is64 : Bool,
                   @initial_ip : USize,
                   @heap_start : USize,
                   @mmap_list : Slice(MemMapHeader))
    end
  end

  def p_flags_to_mmap_attrs(p_flags)
    attrs = MemMapNode::Attributes::None
    if p_flags.includes?(ElfStructs::Elf32PFlags::PF_R)
      attrs |= MemMapNode::Attributes::Read
    end
    if p_flags.includes?(ElfStructs::Elf32PFlags::PF_W)
      attrs |= MemMapNode::Attributes::Write
    end
    if p_flags.includes?(ElfStructs::Elf32PFlags::PF_X)
      attrs |= MemMapNode::Attributes::Execute
    end
    attrs
  end

  def read(node : VFSNode, allocator : StackAllocator, &block)
    state = ParserState::Start
    buffer = Slice(UInt8).null

    elf_class = 0
    e_shoff = 0u32
    n_pheader = 0
    max_pheader = 0

    idx_h = 0u32
    total_bytes = 0u32
    node.read(allocator: allocator) do |byte|
      case state
      when ParserState::Start
        case idx_h
        when EI_MAG0
          return ParserError::InvalidElfHdr if byte != 0x7f
        when EI_MAG1
          return ParserError::InvalidElfHdr if byte != 'E'.ord
        when EI_MAG2
          return ParserError::InvalidElfHdr if byte != 'L'.ord
        when EI_MAG3
          return ParserError::InvalidElfHdr if byte != 'F'.ord
        when EI_CLASS
          elf_class = byte
        when ELF_EIDENT_SZ - 1
          case elf_class
          when ELFCLASS32
            buffer = Slice(UInt8).mmalloc_a sizeof(ElfStructs::Elf32Header), allocator
            state = ParserState::ElfHeader
          when ELFCLASS64
            buffer = Slice(UInt8).mmalloc_a sizeof(ElfStructs::Elf64Header), allocator
            state = ParserState::ElfHeader64
          else
            return ParserError::InvalidElfHdr
          end
          idx_h = 0
          total_bytes += 1
          next
        end
        idx_h += 1
      when ParserState::ElfHeader
        buffer[idx_h] = byte
        idx_h += 1
        if idx_h == sizeof(ElfStructs::Elf32Header)
          header = buffer.to_unsafe.as(ElfStructs::Elf32Header*)

          e_shoff = header.value.e_shoff
          max_pheader = header.value.e_phnum

          unless header.value.e_phentsize == sizeof(ElfStructs::Elf32ProgramHeader)
            return ParserError::InvalidProgramHdrSz
          end
          yield ElfHeader.new(false,
            header.value.e_phnum,
            header.value.e_shnum,
            header.value.e_entry.to_usize)

          if header.value.e_phoff == total_bytes + 1
            buffer = Slice(UInt8).mmalloc_a sizeof(ElfStructs::Elf32ProgramHeader), allocator
            state = ParserState::ProgramHeader
            idx_h = 0
          else
            return ParserError::ExpectedProgramHdr
          end
        end
      when ParserState::ElfHeader64
        buffer[idx_h] = byte
        idx_h += 1
        if idx_h == sizeof(ElfStructs::Elf64Header)
          header = buffer.to_unsafe.as(ElfStructs::Elf64Header*)

          e_shoff = header.value.e_shoff.to_u32
          max_pheader = header.value.e_phnum

          unless header.value.e_phentsize == sizeof(ElfStructs::Elf64ProgramHeader)
            return ParserError::InvalidProgramHdrSz
          end
          yield ElfHeader.new(true,
            header.value.e_phnum,
            header.value.e_shnum,
            header.value.e_entry.to_usize)

          if header.value.e_phoff == total_bytes + 1
            buffer = Slice(UInt8).mmalloc_a sizeof(ElfStructs::Elf64ProgramHeader), allocator
            state = ParserState::ProgramHeader64
            idx_h = 0
          else
            return ParserError::ExpectedProgramHdr
          end
        end
      when ParserState::ProgramHeader
        buffer[idx_h] = byte
        idx_h += 1
        if idx_h == sizeof(ElfStructs::Elf32ProgramHeader)
          pheader = buffer.to_unsafe.as(ElfStructs::Elf32ProgramHeader*)
          yield MemMapHeader.new(pheader.value.p_offset.to_u64,
            pheader.value.p_filesz.to_u64,
            pheader.value.p_vaddr.to_u64,
            pheader.value.p_memsz.to_u64,
            p_flags_to_mmap_attrs(pheader.value.p_flags))
          n_pheader += 1
          idx_h = 0
        end
        if n_pheader == max_pheader
          state = ParserState::Byte
          idx_h = 0
        end
      when ParserState::ProgramHeader64
        buffer[idx_h] = byte
        idx_h += 1
        if idx_h == sizeof(ElfStructs::Elf64ProgramHeader)
          pheader = buffer.to_unsafe.as(ElfStructs::Elf64ProgramHeader*)
          yield MemMapHeader.new(pheader.value.p_offset.to_u64,
            pheader.value.p_filesz.to_u64,
            pheader.value.p_vaddr.to_u64,
            pheader.value.p_memsz.to_u64,
            p_flags_to_mmap_attrs(pheader.value.p_flags))
          n_pheader += 1
          idx_h = 0
        end
        if n_pheader == max_pheader
          state = ParserState::Byte
          idx_h = 0
        end
      when ParserState::Byte
        if total_bytes < e_shoff
          yield Tuple.new(total_bytes, byte)
        else
          break
        end
        # TODO section headers
      else
        panic "unknown"
      end
      total_bytes += 1
    end
    if total_bytes < sizeof(ElfStructs::Elf32Header)
      return ParserError::InvalidElfHdr
    end
    nil
  end

  # load process code from kernel thread
  def load_from_kernel_thread(node, allocator : StackAllocator)
    unless node.size > 0
      return ParserError::EmptyFile
    end
    is64 = false
    mmap_list = Slice(MemMapHeader).null
    mmap_append_idx = 0
    mmap_idx = 0

    ret_initial_ip = 0u64
    ret_heap_start = 0u64

    result = ElfReader.read(node, allocator) do |data|
      case data
      when ElfHeader
        data = data.as(ElfHeader)
        is64 = data.is64
        ret_initial_ip = data.e_entry.to_usize
        mmap_list = Slice(MemMapHeader).mmalloc_a data.e_phnum.to_i32, allocator
      when MemMapHeader
        data = data.as(MemMapHeader)
        if data.memsz > 0
          mmap_list[mmap_append_idx] = data
          mmap_append_idx += 1

          if data.attrs.includes?(MemMapNode::Attributes::Read)
            section_start = Paging.aligned_floor(data.vaddr.to_u64)
            section_end = Paging.aligned(data.vaddr.to_u64 + data.memsz.to_u64)
            npages = (section_end - section_start) >> 12
            # create page and zero-initialize it
            page_start = Paging.alloc_page_pg_drv(section_start,
              data.attrs.includes?(MemMapNode::Attributes::Write),
              true, npages,
              execute: data.attrs.includes?(MemMapNode::Attributes::Execute))
            zero_page Pointer(UInt8).new(page_start), npages
          end
          # heap should start right after the last segment
          heap_start = Paging.aligned(data.vaddr.to_usize + data.memsz.to_usize)
          ret_heap_start = Math.max ret_heap_start, heap_start
        end
      when Tuple(UInt32, UInt8)
        offset, byte = data.as(Tuple(UInt32, UInt8))
        if !mmap_list.null? && mmap_idx < mmap_append_idx
          mmap_node = mmap_list[mmap_idx]
          if offset == mmap_node.file_offset + mmap_node.filesz - 1
            mmap_idx += 1
          elsif offset >= mmap_node.file_offset && offset < mmap_node.file_offset + mmap_node.filesz
            ptr = Pointer(UInt8).new(mmap_node.vaddr.to_usize)
            ptr[offset - mmap_node.file_offset] = byte
          end
        end
      end
    end
    if result.nil?
      # pad heap offset
      ret_heap_start += 0x2000
      # allocate the stack
      Result.new(is64, ret_initial_ip, ret_heap_start, mmap_list)
    else
      Paging.free_process_pdpt Paging.current_pdpt.address, false
      result
    end
  end
end
