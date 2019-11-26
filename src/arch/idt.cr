IDT_SIZE            =     256
INTERRUPT_GATE      = 0x8Eu16
KERNEL_CODE_SEGMENT = 0x08u16

private lib Kernel
  {% for i in 0..31 %}
    fun kcpuex{{ i.id }}
  {% end %}
  {% for i in 0..15 %}
    fun kirq{{ i.id }}
  {% end %}

  @[Packed]
  struct Idt
    limit : UInt16
    base : UInt64
  end

  @[Packed]
  struct IdtEntry
    offset_1 : UInt16 # offset bits 0..15
    selector : UInt16 # a code segment selector in GDT or LDT
    ist : UInt8
    type_attr : UInt8 # type and attributes
    offset_2 : UInt16 # offset bits 16..31
    offset_3 : UInt32 # offset bits 32..63
    zero : UInt32
  end

  fun kload_idt(idtr : UInt32)
end

lib IdtData
  struct Registers
    # Pushed by pushad:
    ds,
rbp, rdi, rsi,
r15, r14, r13, r12, r11, r10, r9, r8,
rdx, rcx, rbx, rax : UInt64
    # Interrupt number
    int_no : UInt64
    # Pushed by the processor automatically.
    rip, cs, rflags, userrsp, ss : UInt64
  end

  struct ExceptionRegisters
    # Pushed by pushad:
    ds,
rbp, rdi, rsi,
r15, r14, r13, r12, r11, r10, r9, r8,
rdx, rcx, rbx, rax : UInt64
    # Interrupt number
    int_no, errcode : UInt64
    # Pushed by the processor automatically.
    rip, cs, rflags, userrsp, ss : UInt64
  end
end

alias InterruptHandler = -> Nil

module Idt
  extend self

  # initialize
  IRQ_COUNT = 16
  @@irq_handlers = uninitialized InterruptHandler[IRQ_COUNT]

  def initialize
    {% for i in 0...IRQ_COUNT %}
      @@irq_handlers[{{ i }}] = ->{ nil }
    {% end %}
  end

  def init_interrupts
    X86.outb 0x20, 0x11
    X86.outb 0xA0, 0x11
    X86.outb 0x21, 0x20
    X86.outb 0xA1, 0x28
    X86.outb 0x21, 0x04
    X86.outb 0xA1, 0x02
    X86.outb 0x21, 0x01
    X86.outb 0xA1, 0x01
    X86.outb 0x21, 0x0
    X86.outb 0xA1, 0x0
  end

  # table init
  IDT_SIZE = 256
  @@idtr = uninitialized Kernel::Idt
  @@idt = uninitialized Kernel::IdtEntry[IDT_SIZE]

  def init_table
    @@idtr.limit = sizeof(Kernel::IdtEntry) * IDT_SIZE - 1
    @@idtr.base = @@idt.to_unsafe.address

    # cpu exception handlers
    {% for i in 0..31 %}
      # init_idt_entry {{ i }}, KERNEL_CODE_SEGMENT, (->Kernel.kcpuex{{ i.id }}).pointer.address, INTERRUPT_GATE
    {% end %}

    # hw interrupts
    {% for i in 0..15 %}
      init_idt_entry {{ i + 32 }}, KERNEL_CODE_SEGMENT, (->Kernel.kirq{{ i.id }}).pointer.address, INTERRUPT_GATE
    {% end %}

    Kernel.kload_idt pointerof(@@idtr).address.to_u32
  end

  def init_idt_entry(num : Int32, selector : UInt16, offset : UInt64, type : UInt16)
    idt = Kernel::IdtEntry.new
    idt.offset_1 = (offset & 0xFFFF)
    idt.ist = 0
    idt.selector = selector
    idt.type_attr = type
    idt.offset_2 = (offset >> 16) & 0xFFFF
    idt.offset_3 = (offset >> 32)
    idt.zero = 0
    @@idt[num] = idt
  end

  # handlers
  class_getter irq_handlers

  def register_irq(idx : Int, handler : InterruptHandler)
    @@irq_handlers[idx] = handler
  end

  # status
  @@status_mask = false
  class_property status_mask

  def enable
    if !@@status_mask
      asm("sti")
    end
  end

  def disable
    if !@@status_mask
      asm("cli")
    end
  end

  def lock(&block)
    if @@status_mask
      return yield
    end
    @@status_mask = true
    yield
    @@status_mask = false
  end

  @@switch_processes = false
  class_property switch_processes
end

fun kirq_handler(frame : IdtData::Registers*)
  PIC.eoi frame.value.int_no

  if Idt.irq_handlers[frame.value.int_no].pointer.null?
    Serial.print "no handler for ", frame.value.int_no, "\n"
  else
    Idt.lock do
      Idt.irq_handlers[frame.value.int_no].call
    end
  end

  if frame.value.int_no == 0 && Idt.switch_processes
    # preemptive multitasking...
    if (current_process = Multiprocessing::Scheduler.current_process)
      if current_process.sched_data.time_slice > 0
        # FIXME: context_switch_to_process must be called or cpu won't
        # have current process' context
        current_process.sched_data.time_slice -= 1
        Multiprocessing::Scheduler.context_switch_to_process(current_process)
        return
      end
    end
    Multiprocessing::Scheduler.switch_process(frame)
  end
end

EX_PAGEFAULT = 14

private def dump_frame(frame : IdtData::ExceptionRegisters*)
  {% for id in [
                 "ds",
                 "rbp", "rdi", "rsi",
                 "r15", "r14", "r13", "r12", "r11", "r10", "r9", "r8",
                 "rdx", "rcx", "rbx", "rax",
                 "int_no", "errcode",
                 "rip", "cs", "rflags", "userrsp", "ss",
               ] %}
    Serial.print {{ id }}, "="
    frame.value.{{ id.id }}.to_s Serial, 16
    Serial.print "\n"
  {% end %}
end

fun kcpuex_handler(frame : IdtData::ExceptionRegisters*)
  errcode = frame.value.errcode
  case frame.value.int_no
  when EX_PAGEFAULT
    faulting_address = 0u64
    asm("mov %cr2, $0" : "=r"(faulting_address) :: "volatile")

    present = (errcode & 0x1) == 0
    rw = (errcode & 0x2) != 0
    user = (errcode & 0x4) != 0
    reserved = (errcode & 0x8) != 0
    id = (errcode & 0x10) != 0

    Serial.print Pointer(Void).new(faulting_address), user, " ", Pointer(Void).new(frame.value.rip), "\n"

    {% if false %}
      process = Multiprocessing::Scheduler.current_process.not_nil!
      if process.kernel_process?
        panic "segfault from kernel process"
      elsif frame.value.rip > KERNEL_OFFSET
        panic "segfault from kernel"
      else
        if faulting_address < Multiprocessing::USER_STACK_TOP &&
           faulting_address > Multiprocessing::USER_STACK_BOTTOM_MAX
          # stack page fault
          Idt.lock do
            stack_address = Paging.t_addr(faulting_address)
            process.udata.not_nil!.mmap_list.add(stack_address, 0x1000,
              MemMapNode::Attributes::Read | MemMapNode::Attributes::Write | MemMapNode::Attributes::Stack)

            addr = Paging.alloc_page_pg(stack_address, true, true)
            zero_page Pointer(UInt8).new(addr)
          end
          return
        else
          Multiprocessing::Scheduler.switch_process_and_terminate
        end
      end
    {% end %}
  else
    dump_frame(frame)
    Serial.print "unhandled cpu exception: ", frame.value.int_no, ' ', errcode, '\n'
    while true; end
  end
end
