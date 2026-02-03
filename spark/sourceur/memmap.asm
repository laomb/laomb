
patch_memmap:
	pushad

	; calculate the physical address of the map buffer
	lea ebx, [str_mem_map_sym]
	call lbf_find_spark_offset

	cmp eax, -1
	je .done

	; calculate the absolute physical address of the destination buffer.
	add eax, dword [bp - 28]
	mov edi, eax

	push edi

	; skip the count word for now.
	add edi, 2

	; accumulator for written entry count.
	xor ebx, ebx

	mov esi, e820_buffer
	xor ecx, ecx
	mov cl, [e820_entry_count]
.copy_loop:
	test ecx, ecx
	jz .copy_done

	; check base or length high dword.
	mov eax, [esi + 4]
	or eax, [esi + 12]
	jnz .next_source

	cmp dword [esi + 16], E820_TYPE_USABLE
	jne .copy_raw

	; stack protocol.
	; word(0) = base
	; word(1) = length

	; push sentinels.
	push dword 0
	push dword 0

	; length.
	mov eax, [esi + 8]
	push eax

	; base.
	mov eax, [esi]
	push eax

.frag_loop:
	pop eax
	pop edx

	; check for sentinels.
	test edx, edx
	jz .next_source

	push ecx
	push ebx

	; load hole start.
	mov ecx, [bp - 28]

	; align hole end to a page.
	mov ebx, [bp - 32]
	add ebx, 0xfff
	and ebx, 0xfffff000
	add ebx, ecx

	; check for overlap.
	cmp eax, ebx
	jae .no_spark

	push edx
	add edx, eax
	cmp ecx, edx
	pop edx

	jae .no_spark

	pop ebx
	pop ecx

	; split into right and left fragment.
	add edx, eax
	push eax

	; recalculate hole end.
	mov eax, [bp - 32]
	add eax, 0xfff
	and eax, 0xfffff000
	add eax, [bp - 28]

	; is there a right fragment?
	sub edx, eax
	jbe .skip_r_spark

	; push right fragment.
	push ebx
	mov ebx, eax
	mov eax, [esp + 4]
	mov [esp + 4], edx
	pop edx

	xchg ebx, edx
	push edx
	jmp .check_l_spark

.skip_r_spark:
	pop eax
.check_l_spark:
	; recalculate hole start, check for left fragment.
	mov edx, [bp - 28]
	sub edx, eax
	jbe .frag_loop

	; push left fragment.
	push edx
	push eax
	jmp .frag_loop

.no_spark:
	pop ebx
	pop ecx

	; check for supervisor.

	push ecx
	push ebx

	; get the hole length and start.
	mov ecx, [bp - 12]
	mov ebx, [bp - 20]
	add ebx, ecx

	; check for overlap.
	cmp eax, ebx
	jae .no_svc
	push edx
	add edx, eax
	cmp ecx, edx
	pop edx
	jae .no_svc

	pop ebx
	pop ecx

	; push right fragment.
	add edx, eax
	push eax

	; recalculate end.
	mov eax, [bp - 20]
	add eax, [bp - 12]

	sub edx, eax
	jbe .skip_r_svc

	; push right fragment.
	push ebx
	mov ebx, eax
	mov eax, [esp + 4]
	mov [esp + 4], edx
	pop edx

	xchg ebx, edx
	push edx
	jmp .check_l_svc

.skip_r_svc:
	pop eax
.check_l_svc:
	; push left fragment.
	mov edx, [bp - 12]
	sub edx, eax
	jbe .frag_loop

	push edx
	push eax
	jmp .frag_loop

.no_svc:
	pop ebx
	pop ecx

	; calculate the end addrss.
	add edx, eax

	; align base up to the next page boundary.
	add eax, 0xfff
	and eax, 0xfffff000

	; align end down to the previous page boundary.
	and edx, 0xfffff000

	; calculate the new length.
	sub edx, eax

	; if the region was consumed by alignment skip it.
	jbe .frag_loop

	; store the aligned base.
	mov dword [edi + SparkMemmapEntry.base], eax

	; store the aligned length.
	mov dword [edi + SparkMemmapEntry.length], edx

	; write the type.
	mov dword [edi + SparkMemmapEntry.type], MEMMAP_TYPE_USABLE

	; advance destination buffer.
	add edi, 12
	inc ebx

	jmp .frag_loop

.copy_raw:
	; copy base.
	mov eax, dword [esi + e820_entry.base]
	mov dword [edi + SparkMemmapEntry.base], eax

	; copy length.
	mov eax, dword [esi + e820_entry.length]
	mov dword [edi + SparkMemmapEntry.length], eax

	; copy type.
	mov eax, dword [esi + e820_entry.type]
	mov dword [edi + SparkMemmapEntry.type], eax

	; advance destination buffer.
	add edi, 12
	inc ebx

.next_source:
	; advance source.
	add esi, 20
	dec ecx
	jmp .copy_loop

.copy_done:
	; inject spark handoff segment.
	mov eax, dword [bp - 28]
	mov [edi], eax

	; align length to 4KiB.
	mov eax, dword [bp - 32]
	add eax, 0xfff
	and eax, 0xfffff000
	mov [edi + SparkMemmapEntry.length], eax

	; write type.
	mov dword [edi + SparkMemmapEntry.type], MEMMAP_TYPE_BOOTLOADER

	add edi, 12
	inc ebx

	; inject supervisor image.
	mov eax, dword [bp - 12]
	mov [edi], eax

	; length is already 4KiB aligned.
	mov eax, dword [bp - 20]
	mov [edi + SparkMemmapEntry.length], eax

	; write type.
	mov dword [edi + SparkMemmapEntry.type], MEMMAP_TYPE_SUPERVISOR

	add edi, 12
	inc ebx

	; write final memmap entry count to the frist word.
	pop edi
	mov [edi], bx

.done:
	popad
	ret
