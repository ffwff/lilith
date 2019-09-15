require "./alloc.cr"
require "./gc/*"

lib LibCrystal
  fun type_offsets="__crystal_malloc_type_offsets"(type_id : UInt32) : UInt32
  fun type_size="__crystal_malloc_type_size"(type_id : UInt32) : UInt32
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

lib Kernel
  struct GcNode
    next_node : GcNode*
    magic : USize
  end
end

module Gc
  extend self

  @@first_white_node = Pointer(Kernel::GcNode).null
  @@first_gray_node = Pointer(Kernel::GcNode).null
  @@first_black_node = Pointer(Kernel::GcNode).null
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
    @@cycles_per_alloc = max((@@last_sweep_tick - @@last_start_tick) >> 2, 1)
  end

  def init(@@data_start : USize, @@data_end : USize,
           @@stack_start : USize, @@stack_end : USize)
    @@enabled = true
  end

  macro push(list, node)
    if {{ list }}.null?
      # first node
      {{ node }}.value.next_node = Pointer(Kernel::GcNode).null
      {{ list }} = {{ node }}
    else
        # middle node
        {{ node }}.value.next_node = {{ list }}
        {{ list }} = {{ node }}
    end
  end

  # gc algorithm
  private def scan_region(start_addr, end_addr, move_list = true)
    # due to the way this rechains the linked list of white nodes
    # please set move_list=false when not scanning for root nodes
    i = start_addr
    fix_white = false
    while i < end_addr - sizeof(Void*)
      word = Pointer(USize).new(i.to_u64).value
      # subtract to get the pointer to the header
      word -= sizeof(Kernel::GcNode)
      if word >= KernelArena.start_addr && word <= KernelArena.placement_addr
        node = @@first_white_node
        prev = Pointer(Kernel::GcNode).null
        found = false
        while !node.null?
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
            debug_mark Pointer(Kernel::GcNode).new(i), node, false
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
            when GC_NODE_MAGIC_BLACK | GC_NODE_MAGIC_BLACK_ATOMIC
              panic "invariance broken"
            else
              # this node is gray
            end
            found = true
            break
          end
          # next it
          prev = node
          node = node.value.next_node
        end
        # debug Pointer(Void).new(word.to_u64), found ? " (found)" : "", "\n"
      end
      i += 1
    end
    fix_white
  end

  private enum CycleType
    Mark
    Sweep
  end

  def cycle
    @@ticks += 1

    # marking phase
    if !@@root_scanned
      # we don't have any gray/black nodes at the beginning of a cycle
      # conservatively scan the stack for pointers
      scan_region @@data_start.not_nil!, @@data_end.not_nil!
      stack_start = 0u64
      asm("mov %rsp, $0" : "=r"(stack_start) :: "volatile")
      if stack_start >= @@stack_start.not_nil! && stack_start <= @@stack_end.not_nil!
        scan_region stack_start, @@stack_end.not_nil!
      else
        panic "stack scanning occurred in non-kernel code"
      end
      @@root_scanned = true
      @@last_start_tick = @@ticks
      
      return CycleType::Mark
    elsif !@@first_gray_node.null?
      # second stage of marking phase: precisely marking gray nodes
      # new_first_gray_node = Pointer(Kernel::GcNode).null

      fix_white = false
      node = @@first_gray_node
      while !node.null?
        debug "node: ", node, "\n"
        if node.value.magic == GC_NODE_MAGIC_GRAY_ATOMIC
          # skip atomic nodes
          debug "skip\n"
          node.value.magic = GC_NODE_MAGIC_BLACK_ATOMIC
          node = node.value.next_node
          next
        end

        debug "magic: ", node, node.value.magic, "\n"
        panic "invariance broken" if node.value.magic == GC_NODE_MAGIC || node.value.magic == GC_NODE_MAGIC_ATOMIC

        node.value.magic = GC_NODE_MAGIC_BLACK

        buffer_addr = node.address + sizeof(Kernel::GcNode) + sizeof(Void*)
        header_ptr = Pointer(USize).new(node.address + sizeof(Kernel::GcNode))
        # get its type id
        type_id = header_ptr[0]
        debug "type: ", type_id, "\n"
        # handle gc array
        if type_id == GC_ARRAY_HEADER_TYPE
          len = header_ptr[1]
          i = 0
          start = Pointer(USize).new(node.address + sizeof(Kernel::GcNode) + GC_ARRAY_HEADER_SIZE)
          while i < len
            addr = start[i]
            if addr >= KernelArena.start_addr && addr <= KernelArena.placement_addr
              # mark the header as gray
              header = Pointer(Kernel::GcNode).new(addr.to_u64 - sizeof(Kernel::GcNode))
              debug_mark node, header
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
        panic "zero offsets" if offsets == 0
        # precisely scan the struct based on the offsets
        pos = 0
        while offsets != 0
          if offsets & 1
            # lookup the buffer address in its offset
            addr = Pointer(USize).new(buffer_addr + pos * sizeof(Void*)).value
            # debug "pointer@", pos, " ", Pointer(Void).new(buffer_addr + pos * POINTER_SZ), " = ", Pointer(Void).new(addr), "\n"
            unless addr >= KernelArena.start_addr && addr <= KernelArena.placement_addr
              # must be a nil union, skip
              pos += 1
              offsets >>= 1
              next
            end
            # mark the header as gray
            header = Pointer(Kernel::GcNode).new(addr - sizeof(Kernel::GcNode))
            debug_mark node, header
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
          pos += 1
          offsets >>= 1
        end
        node = node.value.next_node
      end

      # nodes in @@first_gray_node are now black
      node = @@first_gray_node
      while !node.null?
        next_node = node.value.next_node
        push(@@first_black_node, node)
        node = next_node
      end
      @@first_gray_node = Pointer(Kernel::GcNode).null
      # some nodes in @@first_white_node are now gray
      if fix_white
        debug "fix white nodes\n"
        node = @@first_white_node
        new_first_white_node = Pointer(Kernel::GcNode).null
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
        debug "sweeping phase: ", self, "\n"
        @@last_sweep_tick = @@ticks
        calc_cycles_per_alloc
        node = @@first_white_node
        while !node.null?
          panic "invariance broken" unless node.value.magic == GC_NODE_MAGIC || node.value.magic == GC_NODE_MAGIC_ATOMIC

          # HACK: do this or data corrupts
          no_opt(node.address)

          next_node = node.value.next_node
          KernelArena.free node.address
          node = next_node
        end
        @@first_white_node = @@first_black_node
        node = @@first_white_node
        while !node.null?
          case node.value.magic
          when GC_NODE_MAGIC_BLACK
            node.value.magic = GC_NODE_MAGIC
          when GC_NODE_MAGIC_BLACK_ATOMIC
            node.value.magic = GC_NODE_MAGIC_ATOMIC
          else
            panic "invariance broken"
          end
          node = node.value.next_node
        end
        @@first_black_node = Pointer(Kernel::GcNode).null
        @@root_scanned = false
        # begins a new cycle
        return CycleType::Sweep
      else
        return CycleType::Mark
      end
    end
  end

  def unsafe_malloc(size : USize, atomic = false)
    if @@enabled
      @@cycles_per_alloc.times do |i|
        break if cycle == CycleType::Sweep
      end
    end
    size += sizeof(Kernel::GcNode)
    header = Pointer(Kernel::GcNode).new(KernelArena.malloc(size))
    # move the barrier forwards by immediately graying out the header
    header.value.magic = atomic ? GC_NODE_MAGIC_GRAY_ATOMIC : GC_NODE_MAGIC_GRAY
    # append node to linked list
    if @@enabled
      push(@@first_gray_node, header)
    end
    # return
    ptr = Pointer(Void).new(header.address + sizeof(Kernel::GcNode))
    debug self, '\n' if @@enabled
    ptr
  end

  # printing
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

  def to_s(io)
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

  private def debug(*args)
    return
    Serial.puts *args
  end

  private def debug_mark(parent : Kernel::GcNode*, child : Kernel::GcNode*, node? = true)
    #cbody = child.as(UInt32*) + 2
    #ctype_id = (child + 1).as(UInt32*)[0]
    #if node?
    #  pbody = parent.as(UInt32*) + 2
    #  ptype_id = (parent + 1).as(UInt32*)[0]
    #  #if ctype_id == GC_ARRAY_HEADER_TYPE
    #    Serial.puts "mark ", parent, " (", ptype_id, "): ", child, '\n'
    #  #end
    #else
    #  #if ctype_id == GC_ARRAY_HEADER_TYPE
    #    Serial.puts "mark ", parent, ": ", child, '\n'
    #  #end
    #end
  end
end
