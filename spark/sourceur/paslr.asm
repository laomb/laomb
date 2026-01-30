; [in] eax - nth page
; [in] edi - memory entry (from E820 buffer)
; [uses] ecx, edx
; [out] eax - still n pages remaining
; [out] ecx - page base
find_nth_page_in_region:
	mov ecx, [edi + 0] ; base addr

	; check if ECX is already aligned
	test ecx, 0xFFF
	jz .ecx_aligned

	; align ECX
	and ecx, 0xFFFFF000
	add ecx, 0x1000

	.ecx_aligned:

	; align size
	mov edx, [edi + 8] ; size
	and edx, 0xFFFFF000

	.loop:
	
		add ecx, 0x1000
		sub edx, 0x1000

		test edx, edx
		jz .end

		cmp edx, ebx
		jb .region_too_small

		dec eax
		test eax, eax
		jnz .loop

	.end:
		ret

.region_too_small:
	print 'PASLR: Region too small', 10
	print '       TODO', 10

	jmp $

; [in] eax - random number
; [in] ebx - minimum required size
; [out] eax - base
paslr_find_usable:
	mov edi, e820_buffer
	xor esi, esi

	push eax
	movzx eax, word [memmap_entry_count]
	mov esi, 20
	mul esi
	mov esi, eax
	mov eax, edi
	add esi, eax
	pop eax


	.next:
		add edi, 20
		cmp edi, esi
		jne .dont_reset
	
		mov edi, e820_buffer

	.dont_reset:
		cmp dword [edi + 16], 1 ; usable region
		jne .next ; if not usable, find next

		mov ecx, [edi + 4] ; high 32 bits of base
		test ecx, ecx
		jnz .range_error
		mov ecx, [edi + 12] ; high 32 bits of length
		test ecx, ecx
		jnz .range_error

		call find_nth_page_in_region

		test eax, eax
		jnz .next

	mov eax, ecx

	print 'PA ', eax, 10
		
	ret

.range_error:
	print 'PASLR: region with base/size > 4GiB', 10
	print 'machine too new', 10
	jmp $

