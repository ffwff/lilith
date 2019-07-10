class Process < Gc

    @next : Process | Nil = nil
    @page_dir = Pointer(PageStructs::PageDirectory).null

    def initialize(@page_dir)
    end

    def switch
        alloc_process_page_dir
    end

end