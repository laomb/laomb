
; [in] EBX = size of supervisor in bytes.
; [out] EAX = physical base address of allocation
paslr_find_usable:
	push bp
	mov bp, sp

	; total available slots across all regions.
	sub sp, 4
	mov dword [bp - 4], 0

	push ecx edx esi edi

	mov edi, e820_buffer
	xor esi, esi

	; calculate the end of the buffer into ecx.
	movzx ecx, byte [e820_entry_count]
	imul ecx, 20
	add ecx, edi
.count_loop:
	; if we are at the end of the list, continue to the next stage.
	cmp edi, ecx
	jae .generate_random

	; skip non-usable regions.
	cmp dword [edi + e820_entry.type], E820_TYPE_USABLE
	jne .next_region_count

	; check for high bits of length & base, if non-zero region is out of range.
	cmp dword [edi + 4], 0
	jnz .next_region_count
	cmp dword [edi + 12], 0
	jnz .next_region_count

	mov eax, dword [edi + e820_entry.base]
	mov edx, dword [edi + e820_entry.length]

	; add region slots from this region.
	call calc_region_slots
	add [ebp - 4], eax

.next_region_count:
	add edi, E820_ENTRY_SIZE
	jmp .count_loop

.generate_random:
	; second pass, generate random index.
	cmp dword [ebp - 4], 0
	je .no_memory

	; choose a random slot.
	call rng_get
	xor edx, edx
	div dword [ebp - 4]

	; third pass, find the region containing the target slot
	mov edi, e820_buffer
.find_loop:
	; skip non-usable regions.
	cmp dword [edi + e820_entry.type], E820_TYPE_USABLE
	jne .next_region_find

	; check for high bits of length & base, if non-zero region is out of range.
	cmp dword [edi + 4], 0
	jnz .next_region_find
	cmp dword [edi + 12], 0
	jnz .next_region_find

	mov eax, dword [edi + e820_entry.base]

	push edx
	mov edx, dword [edi + e820_entry.length]
	call calc_region_slots
	pop edx

	cmp edx, eax
	jb .calculate_final_addr

	; not in this region, substract the region's slots from the target.
	sub edx, eax
.next_region_find:
	add edi, E820_ENTRY_SIZE
	jmp .find_loop

.calculate_final_addr:
	mov ecx, dword [edi + e820_entry.base]
	mov eax, dword [edi + e820_entry.length]

	; calculate the region end.
	add eax, ecx
	and eax, 0xfffff000

	; convert slot index to bytes.
	shl edx, 12

	; calculate the final address.
	sub eax, ebx
	sub eax, edx

	pop edi esi edx ecx
	
	add sp, 4
	pop bp
	ret

.no_memory:
	print 'PASLR: No RAM fit for supervisor!', 10
	jmp $

; [in] EAX = region base
; [in] EDX = regon length
; [in] EBX = supervisor size
; [out] EAX = slot count
calc_region_slots:
	push ecx

	; back up start and end of region.
	mov ecx, eax
	add eax, edx

	; align base up (should not be misaligned).
	test ecx, 0xfff
    jz .base_ok

    and ecx, 0xfffff000
    add ecx, 0x1000
.base_ok:
	; align end down.
	and eax, 0xfffff000

	; check if the range is still valid.
	cmp ecx, eax
    jae .zero_slots

	; calculate usable size.
	sub eax, ecx

	; check if it can fit the supervisor.
	cmp eax, ebx
    jb .zero_slots

	; calculate number of usable slots.
	sub eax, ebx
	shr eax, 12
	inc eax

	pop ecx
	ret

.zero_slots:
	xor eax, eax
	pop ecx
	ret
