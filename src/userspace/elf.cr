lib ElfStructs

    # http://www.skyfree.org/linux/references/ELF_Format.pdf

    @[Packed]
    struct Elf32Header
        e_ident     : UInt8[16]
        e_type      : UInt16
        e_machine   : UInt16
        e_version   : UInt32
        e_entry     : UInt32
        e_phoff     : UInt32
        e_shoff     : UInt32
        e_flags     : UInt32
        e_ehsize    : UInt16
        e_phentsize : UInt16
        e_phnum     : UInt16
        e_shentsize : UInt16
        e_shnum     : UInt16
        e_shstrndx  : UInt16
    end

    @[Packed]
    struct Elf32ProgramHeader
        p_type   : UInt32
        p_offset : UInt32
        p_vaddr  : UInt32
        p_paddr  : UInt32
        p_filesz : UInt32
        p_memsz  : UInt32
        p_flags  : UInt32
        p_align  : UInt32
    end

end

module ElfReader

    EI_MAG0       = 0 # 0x7F
    EI_MAG1       = 1 # 'E'
    EI_MAG2       = 2 # 'L'
    EI_MAG3       = 3 # 'F'
    EI_CLASS      = 4 # Architecture (32/64)
    EI_DATA       = 5 # Byte Order
    EI_VERSION    = 6 # ELF Version
    EI_OSABI      = 7 # OS Specific
    EI_ABIVERSION = 8 # OS Specific
    EI_PAD        = 9 # Padding

    def read(node : VFSNode, fs : VFS)
        node.read(fs) do |byte|
        end
    end

end