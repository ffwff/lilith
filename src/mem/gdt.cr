private lib Kernel
    fun kinit_gdtr()
end

module Gdt
    extend self

    def init_table
        Kernel.kinit_gdtr()
    end

end
