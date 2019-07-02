require "../core/proc.cr"
require "../core/static_array.cr"

private lib Kernel

    fun kinit_idtr()

end

module Idt
    extend self

    def init_table
        Kernel.kinit_idtr()
    end

end
