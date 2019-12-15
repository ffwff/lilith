lib LibCrystal
  $__crystal_gc_globals : Void***
  fun type_offsets = "__crystal_malloc_type_offsets"(type_id : UInt32) : UInt32
  fun type_size = "__crystal_malloc_type_size"(type_id : UInt32) : UInt32
end

fun __crystal_malloc64(size : UInt64) : Void*
  Idt.disable(true) do
    Gc.unsafe_malloc size
  end
end

fun __crystal_malloc_atomic64(size : UInt64) : Void*
  Idt.disable(true) do
    Gc.unsafe_malloc size, true
  end
end

module Gc
  extend self

  lib Data
    struct GrayNode
      prev_node : GrayNode*
      next_node : GrayNode*
      ptr : Void*
    end
  end

  # whether the gc is enabled
  @@enabled = false
  class_property enabled

  GRAY_SIZE = 256
  @@front_grays = uninitialized Void*[GRAY_SIZE]
  @@back_grays = uninitialized Void*[GRAY_SIZE]

  @@curr_grays = Pointer(Void*).null
  @@opp_grays = Pointer(Void*).null
  @@curr_grays_idx = 0
  @@opp_grays_idx = 0

  # whether the current gray stack is empty
  private def gray_empty?
    @@curr_grays_idx == 0
  end

  # pushes a node to the current gray stack
  private def push_gray(ptr : Void*)
    return if Allocator.marked?(ptr)
    Allocator.mark ptr
    return if Allocator.atomic?(ptr)
    panic "unable to push gray" if @@curr_grays_idx == GRAY_SIZE
    @@curr_grays[@@curr_grays_idx] = ptr
    @@curr_grays_idx += 1
  end

  # pushes a node to the opposite gray stack
  private def push_opposite_gray(ptr : Void*)
    return if Allocator.marked?(ptr)
    Allocator.mark ptr
    return if Allocator.atomic?(ptr)
    panic "unable to push gray" if @@opp_grays_idx == GRAY_SIZE
    @@opp_grays[@@opp_grays_idx] = ptr
    @@opp_grays_idx += 1
  end

  # pops a node from the current gray stack
  private def pop_gray
    return nil if @@curr_grays_idx == 0
    ptr = @@curr_grays[@@curr_grays_idx - 1]
    @@curr_grays_idx -= 1
    ptr
  end

  # swap gray stacks
  private def swap_grays
    @@curr_grays, @@opp_grays = @@opp_grays, @@curr_grays
    @@curr_grays_idx = @@opp_grays_idx
    @@opp_grays_idx = 0
  end

  private enum State
    ScanRoot
    ScanGray
    Sweep
  end
  @@state = State::ScanRoot

  @@stack_start = Pointer(Void).null
  @@stack_end = Pointer(Void).null

  def init(@@stack_start : Void*, @@stack_end : Void*)
    @@curr_grays = @@front_grays.to_unsafe
    @@opp_grays = @@back_grays.to_unsafe
    @@enabled = true
  end

  private def scan_globals
    global_ptr = LibCrystal.__crystal_gc_globals
    while (ptr = global_ptr.value)
      root_ptr = ptr.value
      if Allocator.contains_ptr? root_ptr
        push_gray root_ptr
      end
      global_ptr += 1
    end
  end

  private def scan_registers
    {% for register in ["rbx", "r12", "r13", "r14", "r15"] %}
      ptr = Pointer(Void).null
      asm("" : {{ "={#{register.id}}" }}(ptr))
      if Allocator.contains_ptr? ptr
        push_gray ptr
      end
    {% end %}
  end

  private def scan_stack
    sp = 0u64
    asm("" : "={rsp}"(sp))
    while sp < @@stack_end.address
      root_ptr = Pointer(Void*).new(sp).value
      if Allocator.contains_ptr? root_ptr
        push_gray root_ptr
      end
      sp += sizeof(Void*)
    end
  end

  private def scan_gray_nodes
    while ptr = pop_gray
      scan_object ptr
    end
  end

  private def scan_object(ptr : Void*)
    # Serial.print ptr, '\n'
    id = ptr.as(UInt32*).value
    if id == GC_ARRAY_HEADER_TYPE
      buffer = ptr.address + sizeof(USize) * 2
      size = ptr.as(USize*)[1]
      # Serial.print "buffer: ", ptr, '\n'
      size.times do |i|
        ivarp = Pointer(Void*).new(buffer + i.to_u64 * sizeof(Void*))
        ivar = ivarp.value
        # Serial.print "ivar: ", ivarp, ": ", ivar,'\n'
        if Allocator.contains_ptr? ivar
          push_opposite_gray ivar
        end
      end
    else
      if id == 0
        # Serial.print "zero: ", ptr, '\n'
        push_opposite_gray ptr
        return
      end
      offsets = LibCrystal.type_offsets id
      pos = 0
      size = LibCrystal.type_size id
      while pos < size
        if (offsets & 1) != 0
          ivar = Pointer(Void*).new(ptr.address + pos).value
          if Allocator.contains_ptr? ivar
            push_opposite_gray ivar
          end
        end
        offsets >>= 1
        pos += sizeof(Void*)
      end
    end
  end

  def cycle
    case @@state
    when State::ScanRoot
      scan_globals
      scan_registers
      scan_stack
      @@state = State::ScanGray
      false
    when State::ScanGray
      scan_gray_nodes
      swap_grays
      if gray_empty?
        @@state = State::Sweep
      end
      false
    when State::Sweep
      Allocator.sweep
      @@state = State::ScanRoot
      true
    end
  end

  def full_cycle
    while true
      return if cycle
    end
  end

  def unsafe_malloc(size : UInt64, atomic = false)
    {% if flag?(:debug_gc) %}
      if enabled
        full_cycle
      end
    {% else %}
      if enabled
        cycle
      end
    {% end %}
    ptr = Allocator.malloc(size, atomic)
    push_gray ptr
    # zero out the first word/qword where type_id is stored
    ptr.as(USize*).value = 0
    ptr
  end

  def dump(io)
    io.print "Gc {\n"
    io.print "  curr_grays ("
    io.print @@curr_grays_idx, "): "
    @@curr_grays_idx.times do |i|
      io.print @@curr_grays[i], ". "
    end
    io.print "\n  opp_grays ("
    io.print @@opp_grays_idx, "): "
    @@opp_grays_idx.times do |i|
      io.print @@opp_grays[i], ". "
    end
    io.print "\n}\n"
  end
end
