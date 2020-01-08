module Syscall::Handlers
  extend self

  def sbrk(args : Syscall::Arguments)
    incr = arg[0].to_i64
    # must be page aligned
    if (incr & 0xfff != 0) || pudata.mmap_heap.nil?
      return 0
    end
    mmap_heap = pudata.mmap_heap.not_nil!
    if incr > 0
      if !mmap_heap.next_node.nil?
        if mmap_heap.end_addr + incr >= mmap_heap.next_node.not_nil!.addr
          # out of virtual memory
          return 0
        end
      end
      npages = incr // 0x1000
      Paging.alloc_page(mmap_heap.end_addr, true, true, npages: npages.to_u64)
      mmap_heap.size += incr
    elsif incr == 0 && mmap_heap.size == 0u64
      if !mmap_heap.next_node.nil?
        if mmap_heap.end_addr + 0x1000 >= mmap_heap.next_node.not_nil!.addr
          # out of virtual memory
          return 0
        end
      end
      Paging.alloc_page(mmap_heap.addr, true, true)
      mmap_heap.size += 0x1000
    elsif incr < 0
      # TODO
      abort "decreasing heap not implemented"
    end
    return mmap_heap.addr + mmap_heap.size - incr
  end

  def mmap(args : Syscall::Arguments)
    fdi = arg[0].to_i32

    prot = Syscall::Data::MmapProt.new(arg[1].to_i32)
    mmap_attrs = MemMapList::Node::Attributes::Read
    if prot.includes?(Syscall::Data::MmapProt::Write)
      mmap_attrs |= MemMapList::Node::Attributes::Write
    end
    if prot.includes?(Syscall::Data::MmapProt::Execute)
      mmap_attrs |= MemMapList::Node::Attributes::Execute
    end

    addr = arg[3]
    size = arg[4]

    if fdi == -1
      if (size & 0xfff) != 0
        return 0
      end
      Paging.alloc_page addr,
        mmap_attrs.includes?(MemMapList::Node::Attributes::Write),
        true, size // 0x1000
      pudata.mmap_list.add(addr, size, mmap_attrs)
      addr
    else
      mmap_attrs |= MemMapList::Node::Attributes::SharedMem
      fd = pudata.get_fd(fdi) || return 0
      if size > fd.node.not_nil!.size
        size = fd.node.not_nil!.size.to_u64
        if (size & 0xfff) != 0
          size = (size & 0xFFFF_F000) + 0x1000
        end
      end
      mmap_node = pudata.mmap_list.space_for_mmap process, size, mmap_attrs
      if mmap_node
        if (retval = fd.node.not_nil!.mmap(mmap_node, process)) == VFS_OK
          mmap_node.shm_node = fd.node
          return mmap_node.addr
        else
          pudata.mmap_list.remove mmap_node
          0
        end
      else
        0
      end
    end
  end

  def munmap(args : Syscall::Arguments)
    addr = args[0]
    size = args[1]
    if pudata.is64
      full_size = size == 0xFFFF_FFFF_FFFF_FFFFu64
    else
      full_size = size == 0xFFFF_FFFFu64
    end
    unless (size & 0xfff) == 0 || full_size
      return EINVAL
    end
    pudata.mmap_list.each do |node|
      if node.addr == addr && (size == node.size || full_size)
        if node.attr.includes?(MemMapList::Node::Attributes::SharedMem)
          node.shm_node.not_nil!.munmap(node.addr, node.size, process)
        else
          i = 0
          while i < node.size
            Paging.remove_page addr + i
            i += 0x1000
          end
        end
        pudata.mmap_list.remove(node)
        return 0
      elsif node.contains_address?(addr) && (node.contains_address?(addr + size) || full_size)
        if node.attr.includes?(MemMapList::Node::Attributes::SharedMem)
          # FIXME: allow partial unmapping of shared memory
          return EINVAL
        end
        size = full_size ? node.end_addr - addr : size
        i = 0
        while i < size
          Paging.remove_page addr + i
          i += 0x1000
        end
        pudata.mmap_list.split_node(node, addr, size)
        return 0
      end
    end
    EINVAL
  end

end
