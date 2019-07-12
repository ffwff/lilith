class MemMapNode < Gc

    @next_node : MemMapNode | Nil = nil
    property next_node

    @file_offset = 0u32
    property file_offset
    @filesz = 0u32
    property filesz
    @vaddr = 0u32
    property vaddr
    @memsz = 0u32
    property memsz

    def initialize(@file_offset, @filesz, @vaddr, @memsz)
    end

end

struct MemMapList

    @last_node : MemMapNode | Nil = nil
    property last_node

    def append(node)
        if !@last_node.nil?
            @last_node.not_nil!.next_node = node
        end
        @last_node = node
    end

end