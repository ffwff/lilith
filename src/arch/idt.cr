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
    offset_1  : UInt16 # offset bits 0..15
    selector  : UInt16 # a code segment selector in GDT or LDT
    ist       : UInt8
    type_attr : UInt8  # type and attributes
    offset_2  : UInt16 # offset bits 16..31
    offset_3  : UInt32 # offset bits 32..63
    zero      : UInt32
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
      #init_idt_entry {{ i }}, KERNEL_CODE_SEGMENT, (->Kernel.kcpuex{{ i.id }}).pointer.address, INTERRUPT_GATE
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
    idt.offset_2 = offset.unsafe_shr(16) & 0xFFFF
    idt.offset_3 = offset.unsafe_shr(32)
    idt.zero = 0
    @@idt[num] = idt
  end

  # handlers
  def irq_handlers
    @@irq_handlers
  end

  def register_irq(idx : Int, handler : InterruptHandler)
    @@irq_handlers[idx] = handler
  end

  # status
  @@status_mask = false

  def status_mask=(@@status_mask); end

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
end

fun kirq_handler(frame : IdtData::Registers*)
  # send EOI signal to PICs
  if frame.value.int_no >= 8
    # send to slave
    X86.outb 0xA0, 0x20
  end
  # send to master
  X86.outb 0x20, 0x20

  if frame.value.int_no == 0 && Multiprocessing.n_process > 1
    # preemptive multitasking...
    Multiprocessing.switch_process(frame)
  end

  if Idt.irq_handlers[frame.value.int_no].pointer.null?
    if frame.value.int_no != 0
      Serial.puts "no handler for ", frame.value.int_no, "\n"
    end
  else
    Idt.irq_handlers[frame.value.int_no].call
  end
end

EX_PAGEFAULT = 14

fun kcpuex_handler(frame : IdtData::ExceptionRegisters*)
  errcode = frame.value.errcode
  case frame.value.int_no
  when EX_PAGEFAULT
    faulting_address = 0u64
    asm("mov %cr2, $0" : "=r"(faulting_address) :: "volatile")

    present  = (errcode & 0x1)  == 0
    rw       = (errcode & 0x2)  != 0
    user     = (errcode & 0x4)  != 0
    reserved = (errcode & 0x8)  != 0
    id       = (errcode & 0x10) != 0

    Serial.puts Pointer(Void).new(faulting_address), user, " ", Pointer(Void).new(frame.value.rip), "\n"
    if Multiprocessing.current_process.not_nil!.kernel_process?
      panic "kernel space"
    else
      if faulting_address < Multiprocessing::USER_STACK_TOP &&
         faulting_address > Multiprocessing::USER_STACK_BOTTOM_MAX
        # stack page fault
        Idt.lock do
          Paging.alloc_page_pg(faulting_address & 0xFFFF_FFFF_FFFF_F000, true, true)
        end
        return
      else
        Multiprocessing.switch_process_and_terminate
      end
    end
  else
    panic "kernel fault: ", frame.value.int_no, ' ', errcode, '\n'
  end
end
