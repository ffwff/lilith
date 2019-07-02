private lib Kernel
    fun kinit_paging()
end

module X86

    def init_paging
        Kernel.kinit_paging()
    end

end