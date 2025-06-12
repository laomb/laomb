use32

GDT_SEL_NULL     = 0x00
GDT_SEL_CODE16   = 0x08
GDT_SEL_DATA16   = 0x10
GDT_SEL_CODE32   = 0x18
GDT_SEL_DATA32   = 0x20

macro gdt_entry name, base, limit, access, flags {
	local lim_lo, lim_hi, base_lo, base_mid, base_hi, gran

	lim_lo   = limit and 0xFFFF
	lim_hi   = (limit shr 16) and 0x0F
	base_lo  = base and 0xFFFF
	base_mid = (base shr 16) and 0xFF
	base_hi  = (base shr 24) and 0xFF
	gran     = (flags and 0xF0) or lim_hi

	name:
		dw lim_lo
		dw base_lo
		db base_mid
		db access
		db gran
		db base_hi
}

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

EMIT_LABEL bootstrap_init_gdt
	use16
	lgdt [gdt_descriptor]
	ret
