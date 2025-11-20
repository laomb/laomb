use32

E820_TYPE_KERNEL = 0x100


; In: EBX = region_base, ECX = region_end, EDI = kernel_base
; Out: CF=0 -> success ; CF=1 -> failure
e820_reserve_kernel:
	pushad

	cmp ebx, ecx
	jae .fail

	cmp edi, ebx
	jb .fail

	cmp edi, ecx
	ja .fail

	movzx ebp, byte [e820_entry_count]
	test ebp, ebp
	jz .fail

	mov esi, e820_buffer

.find_loop:
	mov edx, dword [esi + E820_BASE_HIGH]
	test edx, edx
	jnz .next_entry

	mov edx, dword [esi + E820_LENGTH_HIGH]
	test edx, edx
	jnz .next_entry

	mov eax, dword [esi + E820_TYPE]
	cmp eax, E820_TYPE_USABLE
	jne .next_entry

	mov eax, dword [esi + E820_BASE_LOW]
	mov edx, dword [esi + E820_LENGTH_LOW]

	cmp eax, ebx
	jne .next_entry

	add eax, edx
	jc .next_entry

	cmp eax, ecx
	jne .next_entry

	mov eax, edi
	sub eax, ebx
	mov edx, ecx
	sub edx, edi

	test edx, edx
	jz .fail

	test eax, eax
	jnz .have_lower_part

	mov dword [esi + E820_BASE_LOW], edi
	mov dword [esi + E820_BASE_HIGH], 0
	mov dword [esi + E820_LENGTH_LOW], edx
	mov dword [esi + E820_LENGTH_HIGH], 0
	mov dword [esi + E820_TYPE], E820_TYPE_KERNEL
	jmp .success

.have_lower_part:
	mov dword [esi + E820_BASE_LOW], ebx
	mov dword [esi + E820_BASE_HIGH], 0
	mov dword [esi + E820_LENGTH_LOW], eax
	mov dword [esi + E820_LENGTH_HIGH], 0
	mov dword [esi + E820_TYPE], E820_TYPE_USABLE

	movzx eax, byte [e820_entry_count]
	cmp eax, E820_MAX_ENTRIES
	jae .fail

	imul eax, E820_ENTRY_SIZE
	mov ebp, e820_buffer
	add ebp, eax
	lea eax, [esi + E820_ENTRY_SIZE]
	mov ecx, ebp
	sub ecx, eax

	jz .no_shift

	push edi

	lea edi, [eax + E820_ENTRY_SIZE + ecx - 1]
	lea esi, [eax + ecx - 1]

	std
	rep movsb
	cld

	pop edi

.no_shift:
	mov esi, eax

	mov dword [esi + E820_BASE_LOW], edi
	mov dword [esi + E820_BASE_HIGH], 0
	mov dword [esi + E820_LENGTH_LOW], edx
	mov dword [esi + E820_LENGTH_HIGH], 0
	mov dword [esi + E820_TYPE], E820_TYPE_KERNEL

	inc byte [e820_entry_count]

	jmp .success

.next_entry:
	add esi, E820_ENTRY_SIZE
	dec ebp
	jz .fail

	jmp .find_loop

.success:
	popad
	clc
	ret

.fail:
	popad
	stc
	ret
