define ENDL 13, 10

macro EMIT_LABEL name
{
	name:
	display "~LABEL ", `name, " = 0x"
	local addr
	addr = name
	hex_digit addr shr 12 and 0xF
	hex_digit addr shr 8 and 0xF
	hex_digit addr shr 4 and 0xF
	hex_digit addr and 0xF
	display 13, 10
}

macro clsscr_rm
{
	pusha
	mov ah, 0x00
	mov al, 0x03
	int 0x10
	popa
}

macro hex_digit val
{
	if val < 10
		display '0' + val
	else
		display 'A' + val - 10
	end if
}


macro enter_real_mode {
	use32
	jmp GDT_SEL_CODE16:.pmode16

.pmode16:
	use16
	mov eax, cr0
	and al, 0FEh
	mov cr0, eax

	jmp 0x0000:.rmode

.rmode:
	xor ax, ax
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	sti
}

macro enter_protected_mode {
	cli

	lgdt [gdt_descriptor]

	mov eax, cr0
	or al, 1
	mov cr0, eax

	jmp GDT_SEL_CODE32:.pmode

.pmode:
	use32
	mov ax, GDT_SEL_DATA32
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
}

macro linear_to_seg_off linear, segreg, reg32, reg16 { ; reg16 should be lower bits of reg32
	mov reg32, linear
	shr reg32, 4

	mov segreg, reg16
	mov reg32, linear
	and reg32, 0x0F
}
