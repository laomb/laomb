use32

gdt_start:
gdt_null: dq 0
    gdt_entry gdt_code16, 0x0000, 0xFFFF, 0x9A, 0x00
    gdt_entry gdt_data16, 0x0000, 0xFFFF, 0x92, 0x00

    gdt_entry gdt_code32, 0x0000, 0xFFFFF, 0x9A, 0xC0
    gdt_entry gdt_data32, 0x0000, 0xFFFFF, 0x92, 0xC0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

bootstrap_init_gdt:
use16
    lgdt [gdt_descriptor]
    ret

GDT_SEL_NULL = 0x00
GDT_SEL_CODE16 = 0x08
GDT_SEL_DATA16 = 0x10
GDT_SEL_CODE32 = 0x18
GDT_SEL_DATA32 = 0x20
