{% if flag?(:kernel) %}
  require "./alloc.cr"
{% else %}
  lib LibC
    fun malloc(size : LibC::SizeT) : Void*
    fun realloc(ptr : Void*, size : LibC::SizeT) : Void*
    fun free(data : Void*)

    fun __libc_heap_start : Void*
    fun __libc_heap_placement : Void*

    fun fprintf(file : Void*, x0 : UInt8*, ...) : Int
    $stderr : Void*
  end
{% end %}

lib LibCrystal
  fun type_offsets = "__crystal_malloc_type_offsets"(type_id : UInt32) : UInt32
  fun type_size = "__crystal_malloc_type_size"(type_id : UInt32) : UInt32

  struct GcNode
    next_node : GcNode*
    magic : USize
  end
end

fun __crystal_malloc64(size : UInt64) : Void*
  Gc.unsafe_malloc size
end

fun __crystal_malloc_atomic64(size : UInt64) : Void*
  Gc.unsafe_malloc size, true
end

# white nodes
private GC_NODE_MAGIC        = 0x45564100
private GC_NODE_MAGIC_ATOMIC = 0x45564101
# gray nodes
private GC_NODE_MAGIC_GRAY        = 0x45564102
private GC_NODE_MAGIC_GRAY_ATOMIC = 0x45564103
# black
private GC_NODE_MAGIC_BLACK        = 0x45564104
private GC_NODE_MAGIC_BLACK_ATOMIC = 0x45564105

module Gc
  extend self

  @@first_white_node = Pointer(LibCrystal::GcNode).null
  @@first_gray_node = Pointer(LibCrystal::GcNode).null
  @@first_black_node = Pointer(LibCrystal::GcNode).null
  @@enabled = false
  @@root_scanned = false

  # Number of garbage collection cycles performed
  @@ticks = 0
  # Last tick when sweep phase was performed
  @@last_sweep_tick = 0
  # Last tick when mark phase was started
  @@last_start_tick = 0
  # Number of cycles to be performed per allocation
  @@cycles_per_alloc = 1

  private def calc_cycles_per_alloc
    old = @@cycles_per_alloc
    @@cycles_per_alloc = Math.max((@@last_sweep_tick - @@last_start_tick) >> 2, 1)
  end

  {% if flag?(:kernel) %}
    def _init(@@data_start : UInt64, @@data_end : UInt64,
              @@stack_start : UInt64, @@stack_end : UInt64)
      @@enabled = true
    end
  {% else %}
    def _init(@@data_start : UInt64, @@data_end : UInt64,
              @@bss_start : UInt64, @@bss_end : UInt64,
              @@stack_end : UInt64)
      @@enabled = true
    end
  {% end %}

  private macro push(list, node)
    if {{ list }}.null?
      # first node
      {{ node }}.value.next_node = Pointer(LibCrystal::GcNode).null
      {{ list }} = {{ node }}
    else
      # middle node
      {{ node }}.value.next_node = {{ list }}
      {{ list }} = {{ node }}
    end
  end

  private def each_node(first_node, &block)
    node = first_node
    prev = Pointer(LibCrystal::GcNode).null
    while !node.null?
      yield node, prev
      prev = node
      node = node.value.next_node
    end
  end

  # gc algorithm
  private def scan_region(start_addr : UInt64, end_addr : UInt64, move_list = true)
    # due to the way this rechains the linked list of white nodes
    # please set move_list=false when not scanning for root nodes
    fix_white = false

    heap_start, heap_placement = {% if flag?(:kernel) %}
                                   {KernelArena.start_addr, KernelArena.placement_addr}
                                 {% else %}
                                   {LibC.__libc_heap_start.address, LibC.__libc_heap_placement.address}
                                 {% end %}

    # FIXME: scan_region fails if overflow checking is enabled
    i = start_addr
    scan_end = end_addr - sizeof(Void*) + 1
    until scan_end.to_usize == i.to_usize
      word = Pointer(USize).new(i).value
      # subtract to get the pointer to the header
      word -= sizeof(LibCrystal::GcNode)
      if word >= heap_start && word <= heap_placement
        each_node(@@first_white_node) do |node, prev|
          if node.address == word
            # word looks like a valid gc header pointer!
            # remove from current list
            if move_list
              if !prev.null?
                prev.value.next_node = node.value.next_node
              else
                @@first_white_node = node.value.next_node
              end
            end
            # add to gray list
            case node.value.magic
            when GC_NODE_MAGIC
              node.value.magic = GC_NODE_MAGIC_GRAY
              if move_list
                push(@@first_gray_node, node)
              end
              fix_white = true
            when GC_NODE_MAGIC_ATOMIC
              node.value.magic = GC_NODE_MAGIC_GRAY_ATOMIC
              if move_list
                push(@@first_gray_node, node)
              end
              fix_white = true
            when GC_NODE_MAGIC_BLACK
              panic "invariance broken"
            when GC_NODE_MAGIC_BLACK_ATOMIC
              panic "invariance broken"
            else
              # this node is gray
            end
            break
          end
        end
      end
      i += 1
    end
    fix_white
  end

  private enum CycleType
    Mark
    Sweep
  end

  def cycle : CycleType
    @@ticks += 1

    # marking phase
    if !@@root_scanned
      # we don't have any gray/black nodes at the beginning of a cycle
      # conservatively scan the stack for pointers
      scan_region @@data_start.not_nil!, @@data_end.not_nil!
      {% unless flag?(:kernel) %}
        # in the kernel, the data and bss section are fused
        scan_region @@bss_start.not_nil!, @@bss_end.not_nil!
      {% end %}

      stack_start = 0u64
      {% if flag?(:i686) %}
        asm("mov %esp, $0" : "=r"(stack_start) :: "volatile")
      {% else %}
        asm("mov %rsp, $0" : "=r"(stack_start) :: "volatile")
      {% end %}
      scan_region stack_start, @@stack_end.not_nil!

      @@root_scanned = true
      @@last_start_tick = @@ticks
      return CycleType::Mark
    elsif !@@first_gray_node.null?
      # second stage of marking phase: precisely marking gray nodes
      fix_white = false
      each_node(@@first_gray_node) do |node|
        if node.value.magic == GC_NODE_MAGIC_GRAY_ATOMIC
          # skip atomic nodes
          node.value.magic = GC_NODE_MAGIC_BLACK_ATOMIC
          node = node.value.next_node
          next
        end

        # LibC.fprintf(LibC.stderr, "magic: %x\n", node.value.magic.to_u32)
        panic "invariance broken" if node.value.magic == GC_NODE_MAGIC || node.value.magic == GC_NODE_MAGIC_ATOMIC

        node.value.magic = GC_NODE_MAGIC_BLACK

        buffer_addr = node.address + sizeof(LibCrystal::GcNode) + sizeof(Void*)
        header_ptr = Pointer(USize).new(node.address + sizeof(LibCrystal::GcNode))
        # get its type id
        type_id = header_ptr[0]
        # skip type id = 0
        if type_id == 0
          node = node.value.next_node
          next
        end
        # handle gc array
        if type_id == GC_ARRAY_HEADER_TYPE
          len = header_ptr[1]
          i = 0
          start = Pointer(USize).new(node.address + sizeof(LibCrystal::GcNode) + GC_ARRAY_HEADER_SIZE)
          while i < len
            addr = start[i]
            if addr != 0
              # mark the header as gray
              header = Pointer(LibCrystal::GcNode).new(addr.to_u64 - sizeof(LibCrystal::GcNode))
              # debug_mark node, header
              case header.value.magic
              when GC_NODE_MAGIC
                header.value.magic = GC_NODE_MAGIC_GRAY
                fix_white = true
              when GC_NODE_MAGIC_ATOMIC
                header.value.magic = GC_NODE_MAGIC_GRAY_ATOMIC
                fix_white = true
              else
                # this node is either gray or black
              end
            end
            i += 1
          end
          node = node.value.next_node
          next
        end
        # lookup its offsets
        offsets = LibCrystal.type_offsets type_id
        if offsets == 0
          panic "type_id doesn't have offset\n"
        end
        # precisely scan the struct based on the offsets
        pos = 0
        while offsets != 0
          if offsets & 1
            # lookup the buffer address in its offset
            addr = Pointer(USize).new(buffer_addr + pos * sizeof(Void*)).value.to_u64
            if addr == 0
              # must be a nil union, skip
              pos += 1
              offsets >>= 1
              next
            end
            scan_node = @@first_white_node
            header = Pointer(LibCrystal::GcNode).new(addr - sizeof(LibCrystal::GcNode))
            while !scan_node.null?
              if header.address == scan_node.address
                case header.value.magic
                when GC_NODE_MAGIC
                  header.value.magic = GC_NODE_MAGIC_GRAY
                  fix_white = true
                when GC_NODE_MAGIC_ATOMIC
                  header.value.magic = GC_NODE_MAGIC_GRAY_ATOMIC
                  fix_white = true
                when GC_NODE_MAGIC_GRAY
                  # this node is gray
                when GC_NODE_MAGIC_GRAY_ATOMIC
                  # this node is gray
                else
                  panic "node must be either gray or white\n"
                end
                break
              end
              scan_node = scan_node.value.next_node
            end
          end
          pos += 1
          offsets >>= 1
        end
      end

      # nodes in @@first_gray_node are now black
      node = @@first_gray_node
      while !node.null?
        next_node = node.value.next_node
        push(@@first_black_node, node)
        node = next_node
      end
      @@first_gray_node = Pointer(LibCrystal::GcNode).null
      # some nodes in @@first_white_node are now gray
      if fix_white
        node = @@first_white_node
        new_first_white_node = Pointer(LibCrystal::GcNode).null
        while !node.null?
          next_node = node.value.next_node
          if node.value.magic == GC_NODE_MAGIC || node.value.magic == GC_NODE_MAGIC_ATOMIC
            push(new_first_white_node, node)
            node = next_node
          elsif node.value.magic == GC_NODE_MAGIC_GRAY || node.value.magic == GC_NODE_MAGIC_GRAY_ATOMIC
            push(@@first_gray_node, node)
            node = next_node
          else
            panic "invariance broken"
          end
          node = next_node
        end
        @@first_white_node = new_first_white_node
      end

      if @@first_gray_node.null?
        # sweeping phase
        @@last_sweep_tick = @@ticks
        calc_cycles_per_alloc

        node = @@first_white_node
        while !node.null?
          panic "invariance broken" unless node.value.magic == GC_NODE_MAGIC || node.value.magic == GC_NODE_MAGIC_ATOMIC
          next_node = node.value.next_node
          {% if flag?(:kernel) %}
            KernelArena.free node.as(Void*)
          {% else %}
            LibC.free node.as(Void*)
          {% end %}
          node = next_node
        end

        @@first_white_node = @@first_black_node
        each_node(@@first_white_node) do |node|
          case node.value.magic
          when GC_NODE_MAGIC_BLACK
            node.value.magic = GC_NODE_MAGIC
          when GC_NODE_MAGIC_BLACK_ATOMIC
            node.value.magic = GC_NODE_MAGIC_ATOMIC
          else
            panic "invariance broken"
          end
        end

        @@first_black_node = Pointer(LibCrystal::GcNode).null
        @@root_scanned = false
        return CycleType::Sweep
      else
        return CycleType::Mark
      end
    else
      CycleType::Mark
    end
  end

  def unsafe_malloc(size : UInt64, atomic = false)
    {% if flag?(:kernel) %}
      Multiprocessing::DriverThread.assert_unlocked
    {% end %}

    if @@enabled
      @@cycles_per_alloc.times do |i|
        break if cycle == CycleType::Sweep
      end
    end
    size += sizeof(LibCrystal::GcNode)
    header = {% if flag?(:kernel) %}
               Pointer(LibCrystal::GcNode).new(KernelArena.malloc(size))
             {% else %}
               LibC.malloc(size).as(LibCrystal::GcNode*)
             {% end %}

    # move the barrier forwards by immediately graying out the header
    header.value.magic = atomic ? GC_NODE_MAGIC_GRAY_ATOMIC : GC_NODE_MAGIC_GRAY
    # append node to linked list
    if @@enabled
      push(@@first_gray_node, header)
    end
    # return
    ptr = Pointer(Void).new(header.address + sizeof(LibCrystal::GcNode))
    # dump_nodes if @@enabled
    ptr
  end

  {% unless flag?(:kernel) %}
    private def panic(str)
      abort str
    end

    private macro realloc_if_first_node(node)
      if header.address == \{{ node }}.address
        new_header = LibC.realloc(header, size).as(LibCrystal::GcNode*)
        \{{ node }} = new_header
        new_ptr = Pointer(Void).new(new_header.address + sizeof(LibCrystal::GcNode))
        return new_ptr
      end

      { \{{ node }}.value.next_node, \{{ node }} }
    end

    def realloc(ptr : Void*, size : UInt64)
      size += sizeof(LibCrystal::GcNode)
      header = Pointer(LibCrystal::GcNode).new(ptr.address - sizeof(LibCrystal::GcNode))

      if header.value.magic == GC_NODE_MAGIC_ATOMIC ||
         header.value.magic == GC_NODE_MAGIC
        node, prev = realloc_if_first_node @@first_white_node
      elsif header.value.magic == GC_NODE_MAGIC_GRAY_ATOMIC ||
            header.value.magic == GC_NODE_MAGIC_GRAY
        node, prev = realloc_if_first_node @@first_gray_node
      elsif header.value.magic == GC_NODE_MAGIC_BLACK_ATOMIC ||
            header.value.magic == GC_NODE_MAGIC_BLACK
        node, prev = realloc_if_first_node @@first_black_node
      else
        panic "invalid magic for header"
      end

      while !node.null?
        if node == header
          new_header = LibC.realloc(header, size).as(LibCrystal::GcNode*)
          prev.value.next_node = new_header
          new_ptr = Pointer(Void).new(new_header.address + sizeof(LibCrystal::GcNode))
          return new_ptr
        end
        prev = node
        node = node.value.next_node
      end

      panic "ptr is not managed by the gc"
    end
  {% end %}

  # printing
  {% if flag?(:kernel) %}
    private def out_nodes(io, first_node)
      node = first_node
      while !node.null?
        body = node.as(USize*) + 2
        type_id = (node + 1).as(USize*)[0]
        io.puts body, " (", type_id, ")"
        io.puts ", " if !node.value.next_node.null?
        node = node.value.next_node
      end
    end

    def dump_nodes(io = Serial)
      io.puts "Gc {\n"
      io.puts "  white nodes: "
      out_nodes(io, @@first_white_node)
      io.puts "\n"
      io.puts "  gray nodes: "
      out_nodes(io, @@first_gray_node)
      io.puts "\n"
      io.puts "  black nodes: "
      out_nodes(io, @@first_black_node)
      io.puts "\n"
      io.puts "}"
    end
  {% else %}
    private def out_nodes(first_node)
      node = first_node
      while !node.null?
        body = node.as(USize*) + 2
        type_id = (node + 1).as(USize*)[0]
        LibC.fprintf(LibC.stderr, "%p (%d), ", body, type_id)
        node = node.value.next_node
      end
    end

    def dump_nodes
      LibC.fprintf(LibC.stderr, "Gc {\n")
      LibC.fprintf(LibC.stderr, "  white_nodes: ")
      out_nodes(@@first_white_node)
      LibC.fprintf(LibC.stderr, "\n")
      LibC.fprintf(LibC.stderr, "  gray_nodes: ")
      out_nodes(@@first_gray_node)
      LibC.fprintf(LibC.stderr, "\n")
      LibC.fprintf(LibC.stderr, "  black_nodes: ")
      out_nodes(@@first_black_node)
      LibC.fprintf(LibC.stderr, "\n}\n")
    end
  {% end %}
end
