
GDT_ACCESS_PRESENT 		= 10000000b
GDT_ACCESS_RING0 		= 00000000b
GDT_ACCESS_RING1 		= 00100000b
GDT_ACCESS_RING3 		= 01100000b
GDT_ACCESS_SYSTEM 		= 00010000b
GDT_ACCESS_EXECUTABLE 	= 00001000b
GDT_ACCESS_RW 			= 00000010b
GDT_ACCESS_XO 			= 00000010b

; if set, block size is 4KiB; if cleared, block size is 1 byte.
GDT_FLAG_GRANULARITY 	= 10000000b
; if set, segment is a 32 bit descriptor; if cleared, segment is a 16 bit descriptor.
GDT_FLAG_32BIT 			= 01000000b

GDT_MAX = 512

struct GdtEntry
	limit_low dw ?
	base_low dw ?
	base_mid db ?
	access db ?
	granularity db ?
	base_high db ?
end struct

segment 'TEXT', ST_CODE_XO

; procedure gdt$init();
gdt$init:
	push ebx esi edi es

	mm$SET_FLAT es

	; allocate order 0 page for the gdt.
	xor eax, eax
	call mm$alloc_pages
	jnc .mem_ok

	panic 'Failed to allocate memory for the global descriptor table!'

.mem_ok:
	mov dword [gdt$table_address], eax

	; construct the gdtr on the stack.
	cpu$PUSH_TABLE_DESCRIPTOR (MM_PAGE_SIZE - 1), eax

	; zero out the gdt.
	mov edi, eax
	xor eax, eax
	mov ecx, MM_PAGE_SIZE / dword
	rep stosd

	; dump the old gdtr onto the stack.
	sub esp, 6
	sgdt [esp]

	; load the old gdt size.
	movzx ecx, word [esp]
	inc ecx

	; load the old gdt base and new gdt base.
	mov esi, dword [esp + TableDescriptor.base]
	mov edi, [gdt$table_address]

	; free the old gdtr.
	add esp, 6

	push ecx ds

	; copy the gdt byte for byte.
	mm$SET_FLAT ds
	rep movsb

	pop ds ecx

	; get the number of gdt entries.
	shr ecx, 3

	xor ebx, ebx
.mark_used_loop:
	test ecx, ecx
	jz .mark_done

	bts [gdt$bitmap], ebx

	inc ebx
	dec ecx
	jmp .mark_used_loop

.mark_done:
	; load the gdt from the stack allocated gdtr.
	lgdt [esp]

	; reload descriptor cache to verify everything works.
	push cs
	push .cs_after
	retf

.cs_after:
	mov ax, ds
	mov ds, ax
	mov ax, es
	mov es, ax
	mov ax, ss
	mov ss, ax

	; ensure the null selector isn't allocated.
	bts [gdt$bitmap], 0

	cpu$POP_TABLE_DESCRIPTOR
	pop es edi esi ebx
	ret

; type = flags << 8 | access
;
; function gdt$alloc(base: Cardinal, limit: Cardinal, type: Cardinal): Cardinal;
gdt$alloc:
	push ebx edi ds es

	; gdt limit is last valid address.
	dec edx

	push eax ecx edx

	mm$SET_FLAT es

	mov bx, rel 'DATA'
	mov ds, bx

	; scan 32 bits at a time.
	xor ebx, ebx
.scan_loop:
	cmp ebx, 16
	je .oom

	; read 32 bits from the bitmap.
	mov eax, dword [gdt$bitmap + ebx * 4]
	cmp eax, 0xffffffff
	je .next_chunk

	; found a chunk in it with space, find the first zero bit.
	not eax
	bsf eax, eax

	; calculate the global index.
	shl ebx, 5
	add ebx, eax

	; mark bits as used in the bitmap.
	bts [gdt$bitmap], ebx
	jmp .write_entry

.next_chunk:
	inc ebx
	jmp .scan_loop

.write_entry:
	; calculate a pointer to the descriptor slot.
	mov edi, dword [gdt$table_address]
	lea edi, [edi + ebx * 8]

	pop edx ecx eax

	; write the base low.
	mov word [es:edi + GdtEntry.base_low], ax

	; write base middle.
	shr eax, 16
	mov byte [es:edi + GdtEntry.base_mid], al

	; write base high.
	mov byte [es:edi + GdtEntry.base_high], ah

	; write limit low.
	mov word [es:edi + GdtEntry.limit_low], dx

	; write access byte.
	mov byte [es:edi + GdtEntry.access], cl

	; mask limit high to lower 4 bits.
	shr edx, 16
	and dl, 0xf

	; mask flags to upper 4 bits.
	and ch, 0xf0

	; write the granuality bits containing the limit high and flags.
	or ch, dl
	mov byte [es:edi + GdtEntry.granularity], ch

	; convert to selector and return.
	mov eax, ebx
	shl eax, 3

	clc
	pop es ds edi ebx
	ret

.oom:
	pop edx ecx eax
	stc
	pop es ds edi ebx
	ret

; procedure gdt$free(selector: Word);
gdt$free:
	test ax, ax
	jz .done

	push edi ds es

	mov di, rel 'DATA'
	mov ds, di

	; convert selector to index.
	movzx eax, ax
	shr eax, 3

	; clear bit in bitmap.
	btr [gdt$bitmap], eax

	mm$SET_FLAT es

	; prepare a pointer to the gdt descriptor.
	mov edi, dword [gdt$table_address]
	lea edi, [edi + eax * 8]

	; zero the 8 byte gdt descriptor.
	xor eax, eax
	mov dword [es:edi], eax
	mov dword [es:edi + 4], eax

	pop es ds edi
.done:
	ret

segment 'DATA', ST_DATA_RW

gdt$table_address:
	dd ?

gdt$bitmap:
	dd GDT_MAX / 8 dup(0)
