lib LibCrystal
  $__crystal_gc_globals : Void***
  fun type_offsets = "__crystal_malloc_type_offsets"(type_id : UInt32) : UInt32
  fun type_size = "__crystal_malloc_type_size"(type_id : UInt32) : UInt32
  fun is_markable = "__crystal_is_markable"(type_id : UInt32) : Int32
end

{% if flag?(:kernel) %}
  fun __crystal_malloc64(size : UInt64) : Void*
    Idt.disable(true) do
      GC.unsafe_malloc size
    end
  end

  fun __crystal_malloc_atomic64(size : UInt64) : Void*
    Idt.disable(true) do
      GC.unsafe_malloc size, true
    end
  end

  fun __crystal_realloc64(ptr : Void*, size : UInt64) : Void*
    Idt.disable(true) do
      GC.realloc ptr, size
    end
  end
{% else %}
  fun __crystal_malloc64(size : UInt64) : Void*
    GC.unsafe_malloc size
  end

  fun __crystal_malloc_atomic64(size : UInt64) : Void*
    GC.unsafe_malloc size, true
  end

  fun __crystal_realloc64(ptr : Void*, size : UInt64) : Void*
    GC.realloc ptr, size
  end
{% end %}

class Markable
  {% if flag?(:record_markable) %}
    @markable : UInt64 = 0u64
    def markable?
      @markable == 0
    end

    def write_barrier(&block)
      abort "multiple write barriers" if !markable?
      asm("lea (%rip), $0" : "=r"(@markable) :: "volatile")
      retval = yield
      @markable = 0u64 
      # perform a non stw cycle here so the gray stack
      # doesn't get clogged with write barrier'd classes
      GC.non_stw_cycle
      retval
    end
  {% else %}
    @markable = true
    def markable?
      @markable
    end

    def write_barrier(&block)
      abort "multiple write barriers" if !markable?
      @markable = false
      retval = yield
      @markable = true
      # perform a non stw cycle here so the gray stack
      # doesn't get clogged with write barrier'd classes
      GC.non_stw_cycle
      retval
    end
  {% end %}

  @[NoInline]
  def mark(&block : Void* ->)
    abort "mark isn't implemented!"
  end
end

module GC
  extend self

  lib Data
    struct GrayNode
      prev_node : GrayNode*
      next_node : GrayNode*
      ptr : Void*
    end
  end

  # whether the GC is enabled
  @@enabled = false
  class_getter enabled

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
    abort "unable to push gray" if @@curr_grays_idx == GRAY_SIZE - 1
    @@curr_grays[@@curr_grays_idx] = ptr
    @@curr_grays_idx += 1
  end

  # pushes a node to the opposite gray stack
  private def push_opposite_gray(ptr : Void*)
    return if Allocator.marked?(ptr)
    Allocator.mark ptr
    return if Allocator.atomic?(ptr)
    abort "unable to push gray" if @@opp_grays_idx == GRAY_SIZE - 1
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
    {% if flag?(:kernel) %}
      if Kernel.int_stack_start.address <= sp <= Kernel.int_stack_end.address
        # scan interrupt stack
        while sp < Kernel.int_stack_end.address
          root_ptr = Pointer(Void*).new(sp).value
          if Allocator.contains_ptr? root_ptr
            push_gray root_ptr
          end
          sp += sizeof(Void*)
        end
        # scan kernel stack
        if @@stack_start.address <= Idt.last_rsp <= @@stack_end.address
          sp = Idt.last_rsp
          while sp < @@stack_end.address
            root_ptr = Pointer(Void*).new(sp).value
            if Allocator.contains_ptr? root_ptr
              push_gray root_ptr
            end
            sp += sizeof(Void*)
          end
        end
        return
      elsif (process = Multiprocessing::Scheduler.current_process) && process.kernel_process? && !Syscall.locked
        while sp < Multiprocessing::KERNEL_STACK_INITIAL
          root_ptr = Pointer(Void*).new(sp).value
          if Allocator.contains_ptr? root_ptr
            push_gray root_ptr
          end
          sp += sizeof(Void*)
        end
        return
      end
    {% end %}
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
    # skip if typeid == 0 (nothing is set)
    if id == 0
      push_opposite_gray ptr
      return
    end
    # manual marking
    if LibCrystal.is_markable(id) != 0
      m = ptr.as(Markable)
      if m.markable?
        m.mark do |ivar|
          if Allocator.contains_ptr? ivar
            # Serial.print "mark: ", ivar, '\n'
            push_opposite_gray ivar
          end
        end
      else
        {% if flag?(:record_markable) %}
          Serial.print "not markable: ", ptr,'\n'
        {% end %}
        Allocator.mark ptr, false
        push_opposite_gray ptr
      end
      return
    end
    # mark everything the compiler knows
    offsets = LibCrystal.type_offsets id
    pos = 0
    size = LibCrystal.type_size id
    if size == 0
      # Serial.print ptr, '\n'
      abort "size is 0"
    end
    while pos < size
      if (offsets & 1) != 0
        ivarp = Pointer(Void*).new(ptr.address + pos)
        ivar = ivarp.value
        if Allocator.contains_ptr? ivar
          push_opposite_gray ivar
        end
      end
      offsets >>= 1
      pos += sizeof(Void*)
    end
  end

  {% if flag?(:kernel) %}
    private def scan_kernel_thread_registers(thread)
      {% for register in ["rax", "rbx", "rcx", "rdx",
                          "r8", "r9", "r10", "r11", "rsi", "rdi",
                          "r12", "r13", "r14", "r15"] %}
        ptr = Pointer(Void).new(thread.frame.not_nil!.to_unsafe.value.{{ register.id }})
        if Allocator.contains_ptr? ptr
          push_gray ptr
        end
      {% end %}
    end
    private def scan_kernel_thread_stack(thread)
      # FIXME: uncommenting the debug prints might lead to memory corruption
      # it works if we don't have it though
      rsp = thread.frame.not_nil!.to_unsafe.value.userrsp
      return if rsp == Multiprocessing::KERNEL_STACK_INITIAL
      # virtual addresses
      page_start = Paging.aligned_floor(rsp)
      page_end = Paging.aligned(Multiprocessing::KERNEL_STACK_INITIAL)
      p_offset = rsp & 0xFFF
      #Serial.print "rsp: ", Pointer(Void).new(rsp), ' ', Pointer(Void).new(page_start), ' ', Pointer(Void).new(page_end), '\n'
      while page_start < page_end
        if phys = thread.physical_page_for_address(page_start)
          #Serial.print "phys: ", phys, '\n'
          while p_offset < 0x1000
            root_ptr = Pointer(Void*).new(phys.address + p_offset).value
            if Allocator.contains_ptr? root_ptr
              #Serial.print "root_ptr: ", root_ptr, '\n'
              push_gray root_ptr
            end
            p_offset += sizeof(Void*)
          end
          page_start += 0x1000
          p_offset = 0
        else
          break
        end
      end
    end
    private def scan_kernel_threads
      if threads = Multiprocessing.kernel_threads
        threads.each do |thread|
          # we will only scan threads which can be run
          # so hopefully sleeping threads should have nothing allocated!
          next if thread.sched_data.status != Multiprocessing::Scheduler::ProcessData::Status::Normal
          next if thread.frame.nil?
          next if thread == Multiprocessing::Scheduler.current_process
          # Serial.print "scan: ", thread.name, '\n'
          scan_kernel_thread_registers thread
          scan_kernel_thread_stack thread
        end
      end
    end
  {% end %}

  private def unlocked_cycle
    # Serial.print "---\n"
    case @@state
    when State::ScanRoot
      scan_globals
      scan_registers
      scan_stack
      {% if flag?(:kernel) %}
        scan_kernel_threads
      {% end %}
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

  private def unlocked_full_cycle
    16.times do
      return if unlocked_cycle
    end
  end

  def full_cycle
    @@spinlock.with do
      unlocked_full_cycle
    end
  end

  def non_stw_cycle
    @@spinlock.with do
      if @@state != State::ScanRoot
        unlocked_cycle
      end
    end
  end

  @@spinlock = Spinlock.new

  def unsafe_malloc(size : UInt64, atomic = false)
    @@spinlock.with do
      if @@enabled
        {% if flag?(:debug_gc) %}
          unlocked_full_cycle
        {% else %}
          unlocked_cycle
        {% end %}
      end
      ptr = Allocator.malloc(size, atomic)
      push_gray ptr
      ptr
    end
  end

  def realloc(ptr : Void*, size : UInt64) : Void*
    oldsize = Allocator.block_size_for_ptr(ptr)
    return ptr if oldsize >= size

    @@spinlock.with do
      newptr = Allocator.malloc(size, Allocator.atomic?(ptr))
      memcpy newptr.as(UInt8*), ptr.as(UInt8*), oldsize.to_usize
      push_gray newptr

      if Allocator.marked?(ptr) && @@state != State::ScanRoot
        idx = -1
        @@curr_grays_idx.times do |i|
          if @@curr_grays[i] == ptr
            idx = i
            break
          end
        end
        if idx >= 0
          if idx != @@curr_grays_idx
            memmove (@@curr_grays + idx).as(UInt8*),
              (@@curr_grays + idx + 1).as(UInt8*),
              (sizeof(Void*) * (@@curr_grays_idx - idx - 1)).to_usize
          end
          @@curr_grays_idx -= 1
        end
      end

      newptr
    end
  end

  def dump(io)
    io.print "GC {\n"
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

  {% unless flag?(:kernel) %}
    private def memcpy(dest, src, size)
      LibC.memcpy dest, src, size
    end

    private def memmove(dest, src, size)
      LibC.memmove dest, src, size
    end
  {% end %}
end
