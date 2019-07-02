private lib Kernel
    fun kinit_paging(
        text_start : Void*, text_end : Void*,
        data_start : Void*, data_end : Void*,
        stack_end : Void*, stack_start : Void*
    )
end

module Paging
    extend self

    def init_table(
        text_start : Void*, text_end : Void*,
        data_start : Void*, data_end : Void*,
        stack_end : Void*, stack_start : Void*
    )
        Kernel.kinit_paging(text_start, text_end,
                    data_start, data_end,
                    stack_start, stack_end)
    end

end