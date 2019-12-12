lib LibCrystal
  $__crystal_gc_globals : Void***
  fun type_offsets = "__crystal_malloc_type_offsets"(type_id : UInt32) : UInt32
  fun type_size = "__crystal_malloc_type_size"(type_id : UInt32) : UInt32
end

fun __crystal_malloc64(size : UInt64) : Void*
  Gc.unsafe_malloc size
end

fun __crystal_malloc_atomic64(size : UInt64) : Void*
  Gc.unsafe_malloc size, true
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

  # linked list of current gray nodes
  @@cur_gray = Pointer(Data::GrayNode).null
  # linked list of new gray nodes
  @@new_gray = Pointer(Data::GrayNode).null
  # whether we're in the first stage and the root is scanned
  @@root_scanned = false

  @@stack_start = Pointer(Void).null
  @@stack_end = Pointer(Void).null

  def init(@@stack_start : Void*, @@stack_end : Void*)
    @@enabled = true
  end

  private def scan_globals
    global_ptr = LibCrystal.__crystal_gc_globals
    while true
      ptr = global_ptr.value
      return if ptr.null?
      root_ptr = ptr.value
      if Arena.contains_ptr? root_ptr
        Serial.print "ptr: ", root_ptr, '\n'
      end
      global_ptr += 1
    end
  end

  private def scan_stack
    sp = 0u64
    asm("" : "={rsp}"(sp))
    while sp < @@stack_end.address
      root_ptr = Pointer(Void*).new(sp).value
      if Arena.contains_ptr? root_ptr
        Serial.print root_ptr, '\n'
      end
      sp += 8
    end
  end

  private def scan_gray_nodes
  end

  private def scan_object(ptr : Void*)
  end

  def cycle
    if !@@root_scanned
      @@root_scanned = true
      scan_globals
      scan_stack
    else
    end
  end

  def unsafe_malloc(size : UInt64, atomic = false)
    if enabled
      cycle
    end
    Arena.malloc(size)
  end
end
