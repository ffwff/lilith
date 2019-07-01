private lib Kernel
    fun kinit_gdtr()
end

module X86
    extend self

    def init_gdtr
        Kernel.kinit_gdtr()
    end

end
