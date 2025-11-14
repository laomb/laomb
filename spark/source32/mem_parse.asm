use32


; In: EAX = kernel physical memory size
; Out: CF=0 -> EDI = kernel_load_paddr, EBX = region_base, ECX = region_end
;      CF=1 -> on failure
find_kernel_region:
	push esi edx

	mov ebp, eax
	
	movzx eax, byte [e820_entry_count]
	imul eax, E820_ENTRY_SIZE
	mov esi, e820_buffer
	mov edi, esi
	add edi, eax

	cmp esi, edi
	jae .fail

.scan_loop:
	mov eax, esi
	sub eax, e820_buffer
	xor edx, edx
	mov ecx, E820_ENTRY_SIZE
	div ecx

	print_trace 10, '[E820 #', eax, ']', 10

	mov eax, [esi + E820_BASE_LOW]
	mov edx, [esi + E820_BASE_HIGH]
	print_trace '  base low = 0x', eax, '  base high = 0x', edx, 10

	mov ebx, [esi + E820_LENGTH_LOW]
	mov ecx, [esi + E820_LENGTH_HIGH]
	print_trace '  len  low = 0x', eax, '  len  high = 0x', edx, 10

	mov eax, [esi + E820_TYPE]
	print_trace '  type = 0x', eax, 10

	cmp eax, E820_TYPE_USABLE
	jne .next_entry

	add eax, ebx
	adc edx, ecx

	print_trace '  end  low = 0x', eax, '  end  high = 0x', edx, 10

	test edx, edx
	jnz .next_entry

	sub eax, ebp
	sbb edx, 0

	pushf
	print_trace '  dest_pre(low)=0x', eax, '  dest_pre(high)=0x', edx, 10
	popf

	js .next_entry

	and eax, 0xfffff000
	print_trace '  dest_aligned = 0x', eax, 10

	mov ebx, [esi + E820_BASE_LOW]
	mov ecx, [esi + E820_BASE_HIGH]

	cmp edx, ecx
	jb .next_entry
	ja .fits_here

	cmp eax, ebx
	jb .next_entry

.fits_here:
	mov edx, [best_kernel_base]
	cmp eax, edx
	jbe .next_entry

	mov [best_kernel_base], eax
	mov ebx, [esi + E820_BASE_LOW]
	mov [best_region_base], ebx

	mov eax, [esi + E820_BASE_LOW]
	mov edx, [esi + E820_BASE_HIGH]
	mov ebx, [esi + E820_LENGTH_LOW]
	mov ecx, [esi + E820_LENGTH_HIGH]
	
	add eax, ebx
	adc edx, ecx

	test edx, edx
	jnz .next_entry

	mov [best_region_end], eax

	mov eax, [best_kernel_base]
	print_trace '  NEW BEST dest=0x', eax, 10
	mov eax, [best_region_base]
	print_trace '           base=0x', eax, 10
	mov eax, [best_region_end]
	print_trace '            end=0x', eax, 10

.next_entry:
	add esi, E820_ENTRY_SIZE
	cmp esi, edi
	jb .scan_loop

	mov eax, [best_kernel_base]
	test eax, eax
	jz .fail

	mov edi, eax
	mov ebx, [best_region_base]
	mov ecx, [best_region_end]

	pop edx esi
	clc
	ret

.fail:
	pop edx esi
	stc
	ret

best_kernel_base: dd 0
best_region_base: dd 0
best_region_end: dd 0
