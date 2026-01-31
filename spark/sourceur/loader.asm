define LBF_MAGIC 0x0046424C

ST_CODE_RX = 0
ST_DATA_RO = 1
ST_DATA_RW = 2
ST_STACK_RW = 3

; temporary helper function
print_str:
	push eax
	.loop:

		push ax
		mov al, [eax]
		test al, al
		jz .exit
		call print_char16
		pop ax
		inc eax
		jmp .loop

.exit:
	pop ax
	print 10
	pop eax
	ret

; TODO move this somewhere
; [in] eax = string A
; [in] ebx = string B
; [out] ZF = 1 -> strings match
;            0 -> strings don't match
compare_strings:
	push cx dx
	.loop:

		mov cl, [eax]
		mov dl, [ebx]

		cmp cl, dl
		jne .end

		inc eax
		inc ebx

		; nullbyte
		test cl, cl
		jnz .loop ; not nullbyte
		; is nullbyte, ZF=1, return
	
	.end:

	pop dx cx
	ret

; [in] eax = string offset
; [in] edi = pointer to LBF
; [out] eax = string
ldr_get_string_by_offset:
	push esi

	mov esi, [edi + 24] ; string section
	add esi, edi
	lea eax, [esi + eax]

	pop esi

	ret
	

; [in] ebx = null terminated directory name
; [in] edi = pointer to LBF
; [out] eax = pointer to directory (can be 0)
ldr_get_directory_by_name:
	xor edx, edx
	mov ecx, [edi + 28] ; count
	.loop:
		mov eax, [edi + edx + 32]
		call ldr_get_string_by_offset

		call compare_strings
		jz .found

		add edx, 8
		dec ecx
		jnz .loop
	
	xor eax, eax
	jmp .end

.found:
	mov eax, [edi + edx + 36]
	add eax, edi

.end:
	ret

; [in] edi = pointer to LBF
; [in] esi = pointer to segment header
ldr_print_segments:

	mov ecx, [esi] ; count
	lea edx, [esi + 4]

	.loop:

		mov eax, [edx]
		call ldr_get_string_by_offset

		print '[LDR] dbg: '
		call print_str

		add edx, 24
		dec ecx
		jnz .loop

	ret

; [in] edi = pointer to LBF
; [in] 
ldr_alloc_stack:

	print '[LDR] Allocating stack', 10
	
	mov eax, [edi + 20] ; stack size
	print '[LDR] stack of size = ', eax, 10

	mov ebx, [loom_offset]

	print '[LDR] allocating stack from ', ebx, 10
	print '[LDR]                  size ', eax, 10

	;mov [stack_rw], ebx
	;mov [stack_rw + 4], eax
	add [loom_offset], eax

	ret

; TODO SIMD, move this to a different file
; [in] ecx - destination
; [in] edx - size
zero_memory:
	push ecx edx

	.loop:
		mov byte [ecx], 0

		inc ecx
		dec edx
		jnz .loop

	pop edx ecx

	ret

; TODO SIMD, move this to a different file
; [in] ebx - source
; [in] ecx - destination
; [in] edx - size
copy_memory:
	push eax ebx ecx edx
	.loop:
		mov al, [ebx]
		mov [ecx], al

		inc ebx
		inc ecx
		dec edx
		jnz .loop

	pop edx ecx ebx eax

	ret

; [in] edx = pointer to segment header
ldr_copy_segment:
	push ebx ecx edx
	mov ebx, [edx + 4]
	add ebx, loom_bounce_buffer_flat

	mov ecx, [loom_offset]
	add ecx, [loom_base]

	mov edx, [edx + 8] ; copy on disk size
	call copy_memory

.exit:
	pop edx ecx ebx
	ret

; [in] ecx  = number of segments
; [out] eax = pointer to gdt
ldr_allocate_gdt:

	xor eax, eax

	push ecx

	add ecx, 1 ; null segment
	shl ecx, 3 ; *= descriptor size

	mov ax, cx
	print '[LDR] allocating gdt of ', ax, ' bytes', 10
	sub ax, 1
	mov [gdtr], ax
	add ax, 1
	call arena_alloc16

	print '[LDR] allocated gdt: ', ax, 10

	movzx ecx, ax
	mov [gdtr + 2], ecx
	pop ecx

	ret

; [in] eax = pointer to descriptor
; [in] ebx = limit
ldr_gdt_write_limit:
	mov [eax], bx
	shr ebx, 16

	and bl, 0xF ; sanity check

	and byte [eax + 6], 0xF0
	or [eax + 6], bl

	ret

; [in] ebx = pointer to the descriptor
; [in] eax = base
ldr_gdt_write_base:
	mov [ebx + 2], al
	shr eax, 8

	mov [ebx + 3], al
	shr eax, 8
	mov [ebx + 4], al
	shr eax, 8

	mov [ebx + 7], al

	ret

; [in] ebx = pointer to the descriptor
; [in] al  = access byte
ldr_gdt_write_access:
	mov [ebx + 5], al
	ret

; [in] ebx = pointer to the descriptor
; [in] al  = flags
ldr_gdt_write_flags:
	and al, 0xF ; sanity check
	shl al, 4

	and byte [ebx + 6], 0x0F
	or [ebx + 6], al

	ret
	
; [in]  eax = segment type
; [out] al  = access byte
ldr_access_from_type:

	cmp eax, ST_CODE_RX
	jne .next1
	
	mov al, 0x99 ; A, E, S, P
	ret
	

.next1:
	cmp eax, ST_DATA_RO
	jne .next2

	mov al, 0x91 ; A, S, P
	ret

.next2:

	cmp eax, ST_DATA_RW
	jne .next3

	mov al, 0x93 ; A, RW, S, P
	ret

.next3:
	cmp eax, ST_STACK_RW
	jne .next4

	print '[LDR] ST_STACK_RW not supported', 10
	jmp $

.next4:
	print '[LDR] invalid segment type ', eax, 10
	jmp $

	ret

; [in] edi = pointer to LBF
; [in] esi = pointer to segment header
ldr_load_segments:

	print '[LDR] Loading segments', 10

	mov ecx, [esi] ; count
	lea edx, [esi + 4]

	call ldr_allocate_gdt
	mov ebx, eax
	push ebx

	; null descriptor
	xor eax, eax
	mov [ebx], eax
	mov [ebx + 4], eax

	add ebx, 8

	.loop:
		push ebx
		call ldr_copy_segment

		; Print currently loaded name
		print '[LDR] Loading '
		mov eax, [edx]
		call ldr_get_string_by_offset
		call print_str

		mov eax, [edx + 16] ; segment type
		print '[LDR] gdt addr   = ', ebx, 10
		print '[LDR] type       = ', eax, 10
		call ldr_access_from_type
		call ldr_gdt_write_access

		mov eax, [loom_offset]
		print '[LDR] mem offset = ', eax, 10
		add eax, [loom_base]
		print '[LDR] mem addr   = ', eax, 10

		call ldr_gdt_write_base

		mov eax, [edx + 12] ; mem size
		test eax, 0xFFF
		jz .mem_size_aligned

		and eax, 0xFFFFF000
		add eax, 0x1000

	.mem_size_aligned:
		print '[LDR] mem size   = ', eax, 10
		call ldr_gdt_write_limit
		add [loom_offset], eax

		mov eax, [edx + 4] ; file rva
		print '[LDR] disk rva   = ', eax, 10

		mov eax, [edx + 8] ; file size
		print '[LDR] disk size  = ', eax, 10

		add edx, 24
		pop ebx
		add ebx, 8
		dec ecx
		jnz .loop

	pop ebx

	ret

; [in] edx = pointer to LBF 
; [out] ZF = 1 -> magic number valid
;            0 -> magic number invalid
ldr_check_magic:
	cmp dword [edi], LBF_MAGIC
	jne .err
	ret
	.err:
		print 'loom magic invalid', 10
		jmp $
	

ldr_enable_protected_mode:

	cli

	; set the protected mode bit, from now on segment register access updates the cache.
	mov eax, cr0
	or al, 1
	mov cr0, eax

	; flush the instruction pipeline to ensure we ARE in protected mode.
	jmp $+2

	lgdt [gdtr]

	sti

	ret

ldr_load_loom:
	call rng_get
	and eax, 0xFFFF
	print 'PASLR rng: ', eax, 10

	call paslr_find_usable
	print 'PASLR found usable: ', eax, 10

	mov [loom_base], eax
	mov edi, loom_bounce_buffer_flat
	call ldr_check_magic

	mov ebx, str_segment
	call ldr_get_directory_by_name
	mov esi, eax

	print 'segment: ', eax, 10

	call ldr_alloc_stack
	call ldr_print_segments
	call ldr_load_segments

	mov eax, [loom_base]
	mov ebx, [eax + 8]  ; entry_segment
	add ebx, 1 ; null segment
	shl ebx, 3 ; *= descriptor size
	mov eax, [eax + 12] ; entry_offset

	push eax ebx

	print 'Switching to protected mode', 10
	call ldr_enable_protected_mode

	pop ebx eax

	push word bx
	push word ax
	retf

str_segment:
db 'SEGMENT', 0

loom_base: dd 0

loom_offset: dd 0

gdtr:
dw 0
dd 0
