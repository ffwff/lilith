lib LibCrystal
  $__crystal_gc_globals : Void***
  fun type_offsets = "__crystal_malloc_type_offsets"(type_id : UInt32) : UInt64
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

# A class which objects can inherit from to mark dynamically-sized
# buffers. This is inherited by data structures such as `Array` or `Hash`.
class Markable
  {% if flag?(:record_markable) %}
    @markable : UInt64 = 0u64
    def markable?
      @markable == 0
    end

    # Activates the write barrier for the markable object.
    def write_barrier(&block)
      abort "multiple write barriers" if !markable?
      asm("lea (%rip), $0" : "=r"(@markable) :: "volatile")
      begin
        retval = yield
      ensure
        @markable = 0u64 
        # perform a non stw cycle here so the gray stack
        # doesn't get clogged with write barrier'd classes
        GC.non_stw_cycle
        retval
      end
    end
  {% else %}
    @markable = true
    def markable?
      @markable
    end
    
    # Activates the write barrier for the markable object.
    def write_barrier(&block)
      abort "multiple write barriers" if !markable?
      @markable = false
      begin
        retval = yield
      ensure
        @markable = true
        # perform a non stw cycle here so the gray stack
        # doesn't get clogged with write barrier'd classes
        GC.non_stw_cycle
        retval
      end
    end
  {% end %}

  # Marks any object connected to the markable object.
  @[NoInline]
  def mark(&block : Void* ->)
    abort "mark isn't implemented!"
  end
end

# A simple hybrid conservtive-precise incremental garbage collector.
# The GC uses the tri-color marking algorithm, storing whether or not 
# the object is marked in the `Allocator` pool's metadata bitmap.
# Gray nodes are stored in two internal fixed-size gray stacks (a front and a back stack),
# one of which is scanned each cycle (after root nodes have been scanned).
#
# The GC starts by scanning roots in the data segment (by marking and graying
# out pointers in the null-terminated pointer array `__crystal_gc_globals`),
# and scanning roots conservatively. This part of the cycle stops the world,
# as this cycle usually has long pause times. Once every root has been marked,
# they are pushed into the gray stack, adn the collector transitions into
# the gray-scanning cycle.
# 
# The collector then pops and scans each object in the front stack, precisely marking every
# pointer contained within the object (based on marking data exposed by the compiler
# in the `__crystal_malloc_type_offsets`), pushing the newly marked pointer into the back gray
# stack. After each gray-scanning cycle, the front stack and the back stack is swapped.
# Once the back stack is empty, the collector transitions into the sweep cycle.
#
# On the sweep cycle, we call `Allocator.sweep` to scan the heap and freeing every marked object.
# The collector resets to the initial state.
#
# ### See also
#
# See `Allocator` for more information.
module GC
  extend self

  @@enabled = false
  # whether the GC is enabled
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
    if ptr = Allocator.make_markable(ptr)
      Allocator.mark ptr
      return if Allocator.atomic?(ptr)
      abort "unable to push gray" if @@curr_grays_idx == GRAY_SIZE - 1
      @@curr_grays[@@curr_grays_idx] = ptr
      @@curr_grays_idx += 1
    end
  end

  # pushes a node to the opposite gray stack
  private def push_opposite_gray(ptr : Void*)
    if ptr = Allocator.make_markable(ptr)
      Allocator.mark ptr
      return if Allocator.atomic?(ptr)
      abort "unable to push gray" if @@opp_grays_idx == GRAY_SIZE - 1
      @@opp_grays[@@opp_grays_idx] = ptr
      @@opp_grays_idx += 1
    end
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

  # Initializes the garbage collector and enables it.
  def init(@@stack_start : Void*, @@stack_end : Void*)
    @@curr_grays = @@front_grays.to_unsafe
    @@opp_grays = @@back_grays.to_unsafe
    @@enabled = true
  end

  # Scans the global variables specified in __crystal_gc_globals.
  private def scan_globals
    global_ptr = LibCrystal.__crystal_gc_globals
    while (ptr = global_ptr.value)
      root_ptr = ptr.value
      push_gray root_ptr
      global_ptr += 1
    end
  end

  # Scans registers.
  private def scan_registers
    {% for register in ["rbx", "r12", "r13", "r14", "r15"] %}
      ptr = Pointer(Void).null
      asm("" : {{ "={#{register.id}}" }}(ptr))
      push_gray ptr
    {% end %}
  end

  # Conservatively scan a data segment.
  private def conservative_scan(from : UInt64, to : UInt64)
    i = from
    while i < to
      root_ptr = Pointer(Void*).new(i).value
      push_gray root_ptr
      i += sizeof(Void*)
    end
  end

  # Scans the call stack before GC.cycle was called.
  private def scan_stack
    sp = 0u64
    asm("" : "={rsp}"(sp))
    {% if flag?(:kernel) %}
      if Multiprocessing::KERNEL_INITIAL <= sp <= Multiprocessing::KERNEL_STACK_INITIAL
        conservative_scan(sp, Multiprocessing::KERNEL_STACK_INITIAL)
        return
      end
    {% end %}
    conservative_scan(sp, @@stack_end.address)
  end

  # Scans the list of gray nodes.
  private def scan_gray_nodes
    while ptr = pop_gray
      scan_object ptr
    end
  end

  # Scans an object.
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
          # Serial.print "mark: ", ivar, '\n'
          push_opposite_gray ivar
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
      if (offsets & 1u64) != 0u64
        ivarp = Pointer(Void*).new(ptr.address + pos)
        ivar = ivarp.value
        push_opposite_gray ivar
      end
      offsets >>= 1u64
      pos += sizeof(Void*)
    end
  end

  {% if flag?(:kernel) %}
    private def scan_kernel_thread_registers(thread)
      {% for register in ["rax", "rbx", "rcx", "rdx",
                          "r8", "r9", "r10", "r11", "rsi", "rdi",
                          "r12", "r13", "r14", "r15"] %}
        ptr = Pointer(Void).new(thread.frame.{{ register.id }})
        push_gray ptr
      {% end %}
    end

    private def scan_kernel_thread_stack(thread)
      page_end = Multiprocessing::KERNEL_STACK_INITIAL + 1
      page_start = page_end - thread.kdata.stack_pages * 0x1000
      while page_start < page_end
        if phys = thread.physical_page_for_address(page_start)
          conservative_scan(phys.address, phys.address+0x1000u64)
          page_start += 0x1000
        else
          break
        end
      end
    end

    # NOTE: must be called from context switching
    def scan_kernel_threads_if_necessary
      if @@needs_scan_kernel_threads
        if threads = Multiprocessing.kernel_threads
          threads.each do |thread|
            next unless thread.frame_initialized && thread.kdata.gc_enabled
            scan_kernel_thread_registers thread
            scan_kernel_thread_stack thread
          end
        end
        @@needs_scan_kernel_threads = false
      end
    end

    private def scan_frame_registers(frame)
      {% for register in ["rax", "rbx", "rcx", "rdx",
                          "r8", "r9", "r10", "r11", "rsi", "rdi",
                          "r12", "r13", "r14", "r15"] %}
        ptr = Pointer(Void).new(frame.value.{{ register.id }})
        push_gray ptr
      {% end %}
    end

    @@needs_scan_kernel_threads = false

    @@needs_scan_kernel_stack = false
    class_setter needs_scan_kernel_stack

    @@needs_scan_interrupt = false
    class_setter needs_scan_interrupt
  {% end %}

  private def unlocked_cycle
    # Serial.print "---\n"
    {% if flag?(:kernel) %}
      case @@state
      when State::ScanRoot
        scan_globals
        scan_registers
        scan_stack
        @@state = State::ScanGray
        @@needs_scan_kernel_stack = false
        false
      when State::ScanGray
        scan_gray_nodes
        swap_grays
        if @@needs_scan_kernel_stack
          if @@needs_scan_interrupt && Idt.last_frame
            # we're in an interrupt which came from a syscall
            scan_frame_registers Idt.last_frame
          end
          conservative_scan @@stack_start.address,
                            @@stack_end.address
          @@needs_scan_kernel_stack = false
        end
        if @@needs_scan_interrupt
          conservative_scan Kernel.int_stack_start.address,
            Kernel.int_stack_end.address
          @@needs_scan_interrupt = false
        end
        if gray_empty? &&
           !@@needs_scan_kernel_threads
          @@state = State::Sweep
        end
        false
      when State::Sweep
        Allocator.sweep
        @@state = State::ScanRoot
        @@needs_scan_kernel_threads = true
        @@needs_scan_interrupt = true
        @@needs_scan_kernel_stack = false
        true
      end
    {% else %}
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
    {% end %}
  end

  private def unlocked_full_cycle
    16.times do
      return if unlocked_cycle
    end
  end

  # Tries to do at most 16 GC cycles, stopping upon a sweep stage.
  @[NoInline]
  def full_cycle
    @@spinlock.with do
      return unless @@enabled
      unlocked_full_cycle
    end
  end

  # Tries to do a non stop-the-world cycle.
  @[NoInline]
  def non_stw_cycle
    @@spinlock.with do
      return unless @@enabled
      if @@state != State::ScanRoot
        unlocked_cycle
      end
    end
  end

  @@spinlock = Spinlock.new

  # Allocates an object and marks it gray.
  #
  # NOTE: this must be NoInline which forces the compiler to store the caller's local variables inside a stack frame.
  @[NoInline]
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

  # Resizes an object to `size`, returning itself (if there is still space available) or a new pointer.
  #
  # NOTE: see `unsafe_malloc`
  @[NoInline]
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

  # Dumps the GC state into `io`.
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
