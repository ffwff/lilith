lib AoutFormat

    @[Packed]
    struct Header
        a_midmag : UInt32
        a_text   : UInt32
        a_data   : UInt32
        a_bss    : UInt32
        a_syms   : UInt32
        a_entry  : UInt32
        a_trsize : UInt32
        a_drsize : UInt32
    end

end