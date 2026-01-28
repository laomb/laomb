
ur_bootstrap:
	mov bp, sp
	sub bp, 6

	; prepare the gdtr on the stack.
	mov word [bp], gdt_end - gdt_start - 1
	mov dword [bp + 2], gdt_start

	; clear IF and load the temporary global descriptor table.
	cli
	lgdt [bp]

	; set the protected mode bit, from now on segment register access updates the cache.
	mov eax, cr0
	or al, 1
	mov cr0, eax

	; flush the instruction pipeline to ensure we ARE in protected mode.
	jmp $+2

	; load the data segment into DS & ES.
	mov bx, 0x08
	mov ds, bx
	mov es, bx

	; clear the protected mode bit, we are back in real mode.
	mov eax, cr0
	and al, 0xfe
	mov cr0, eax

	; zero out the segment registers for a flat 4GiB model.
	xor ax, ax
	mov ds, ax
	mov es, ax

	; reenable interrupts, BIOS calls should be safe now.
	sti

	; fast a20 gate enable.
	in al, 0x92
	or al, 2
	out 0x92, al

	jmp ldr_load_loom

gdt_start:
	dq 0x0

	dw 0xffff
	dw 0x0
	db 0x0
	db 10010010b
	db 11001111b
	db 0x0
gdt_end:
