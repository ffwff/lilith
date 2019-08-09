.section .multiboot
.set MBOOT_HEADER_MAGIC, 0x1BADB002
.set MBOOT_PAGE_ALIGN,   1 << 0
.set MBOOT_MEM_INFO,     1 << 1
.set MBOOT_VID_INFO,     1 << 2
.set MBOOT_HEADER_FLAGS, MBOOT_PAGE_ALIGN | MBOOT_MEM_INFO | MBOOT_VID_INFO
.set MBOOT_CHECKSUM,     -(MBOOT_HEADER_MAGIC + MBOOT_HEADER_FLAGS)

# multiboot spec
.align 4
.long MBOOT_HEADER_MAGIC        # magic
.long MBOOT_HEADER_FLAGS        # flags
.long MBOOT_CHECKSUM            # checksum. m+f+c should be zero
.long 0, 0, 0, 0, 0
.long 0 # 0 = set graphics mode
.long 1024, 768, 32 # Width, height, depth

.section .text
.global _bootstrap_start
_bootstrap_start:
    hlt
