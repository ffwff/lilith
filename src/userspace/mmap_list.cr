class MemMapNode
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
