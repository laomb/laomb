use32



macro __bitmap_addr_from_block32
	mov ebx, esi
	mov ecx, esi
	shr ebx, 3
	and ecx, 7
	mov dl, 1
	shl dl, cl
	add ebx, heap_base

	assert "[__bitmap_addr_from_block32] bx overflow", ebx lt heap_limit
	assert "[__bitmap_addr_from_block32] bx underflow", ebx gte heap_base
end macro


; In: ESI = block index
; Out: ZF=1 -> free (bit=0)
; 	   ZF=0 -> used (bit=1), AL = byte, DL = mask
is_block_used32:
	push esi
	__bitmap_addr_from_block32
	mov al, [ebx]
	test al, dl
	pop esi
	ret


; In: ESI = block index
mark_block_used32:
	pushad
	assert "[mark_block_used32] invalid block index", esi lt total_blocks
	__bitmap_addr_from_block32
	mov al, [ebx]
	or al, dl
	mov [ebx], al
	popad
	ret


; In: ESI = block index
mark_block_free32:
	pushad
	assert "[mark_block_free32] invalid block index", esi lt total_blocks
	__bitmap_addr_from_block32
	mov al, [ebx]
	not dl
	and al, dl
	not dl
	mov [ebx], al
	popad
	ret



; In: ECX = number of contiguous blocks requested
; Out: CF=0 -> ESI = header_block_index ; CF=1 -> not found
find_free_run32:
	assert "[find_free_run32] ecx=0 invalid", ecx gt 0
	push edx edi

	xor edi, edi
	mov esi, data_first_block

.ffr_next:
	cmp esi, total_blocks
	jae .ffr_fail

	push ecx
	call is_block_used32
	pop ecx
	jnz .used

	cmp edi, 0
	jne .cont
	mov edx, esi
.cont:
	inc edi
	cmp edi, ecx
	je .ok
	inc esi
	jmp .ffr_next

.used:
	xor edi, edi
	inc esi
	jmp .ffr_next

.ok:
	mov esi, edx
	clc
	pop edi edx
	ret

.ffr_fail:
	stc
	pop edi edx
	ret


; In:  EAX = bytes to allocate
; Out: CF=0 -> EAX = linear pointer to user memory
;      CF=1 -> fail
mem_alloc32:
	push edx ecx ebx esi edi

	mov edx, eax
	add edx, (block_size - 1)
	shr edx, block_shift
	mov ecx, edx
	inc ecx

	call find_free_run32
	jc .fail

	mov edi, ecx
	mov ebx, esi

.mark_loop:
	call mark_block_used32
	inc esi
	dec ecx
	jnz .mark_loop

	mov esi, ebx
	mov eax, esi
	shl eax, block_shift
	add eax, heap_base
	mov [eax], di
	mov dx, magic_word
	mov [eax + 2], dx

	mov eax, ebx
	inc eax
	shl eax, block_shift
	add eax, heap_base

	clc
	pop edi esi ebx ecx edx
	ret

.fail:
	stc
	pop edi esi ebx ecx edx
	ret


; In:  EAX = pointer to user memory
; Out: CF=0 -> ok ; CF=1 -> error
mem_free32:
	push edx ecx ebx esi

	assert "[mem_free32] invalid free", eax gte heap_base, eax lt heap_limit

	mov ebx, eax
	sub ebx, heap_base
	shr ebx, block_shift
	assert "[mem_free32] attempted free in bitmap", ebx gt data_first_block

	dec ebx
	mov esi, ebx

	mov edx, esi
	shl edx, block_shift
	add edx, heap_base
	movzx ecx, word [edx]
	mov dx, [edx + 2]
	cmp dx, magic_word
	jne .corrupt

.free_loop:
	call mark_block_free32
	inc esi
	dec ecx
	jnz .free_loop

	clc
	pop esi ebx ecx edx
	ret

.corrupt:
	panic "[mem_free32] heap corruption"
