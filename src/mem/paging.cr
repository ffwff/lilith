private lib Kernel
    fun kinit_paging(text_start : UInt32, text_end : UInt32, stack_start : UInt32, stack_end : UInt32)
end

module X86

    def init_paging(text_start : UInt32, text_end : UInt32, stack_start : UInt32, stack_end : UInt32)
        Kernel.kinit_paging text_start, text_end, stack_start, stack_end
    end

end