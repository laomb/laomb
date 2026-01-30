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

	mov [stack_segment], ebx
	add [loom_offset], eax

	ret

; [in] eax = segment type
; [out] eax = pointer to segment info (global)
get_seg_ptr_from_type:

	cmp eax, ST_CODE_RX
	jne .next1
	
	mov eax, code_rx
	ret

.next1:
	cmp eax, ST_DATA_RW
	jne .next2

	mov eax, data_rw
	ret

.next2:
	cmp eax, ST_DATA_RO
	jne .next3

	mov eax, data_ro
	ret

.next3:

	cmp eax, ST_STACK_RW
	jne .next4

	print 'Segment type cant be ST_STACK_RW', 10
	jmp $

.next4:
	print 'Invalid segment type ', eax, 10
	jmp $

	ret

; [in] edi = pointer to LBF
; [in] esi = pointer to segment header
; [out] writes to the segment globals at the bottom of this file
ldr_parse_segments:

	print '[LDR] Loading segments', 10

	mov ecx, [esi] ; count
	lea edx, [esi + 4]

	.loop:

		mov eax, [edx + 16] ; segment type
		call get_seg_ptr_from_type

		mov ebx, [eax]
		test ebx, ebx
		jnz .already_has

		; Print currently loaded name
		push eax
		print '[LDR] Loading '
		mov eax, [edx]
		call ldr_get_string_by_offset
		call print_str
		pop eax

		push ecx
		mov ecx, [loom_offset]
		mov [eax], ecx
		mov ecx, [edx + 12] ; mem size
		print '[LDR] mem size = ', ecx, 10
		mov [eax + 4], ecx
		add [loom_offset], ecx

		mov ecx, [edx + 4] ; file rva
		print '[LDR] on disk rva = ', ecx, 10
		mov [eax + 8], ecx

		mov ecx, [edx + 8] ; file size
		print '[LDR] on disk size = ', ecx, 10
		mov [eax + 12], ecx

		pop ecx

		add edx, 24
		dec ecx
		jnz .loop

	ret

.already_has:
	print '[LDR] Duplicate segment of type '
	mov eax, [eax + 16]
	call print_str

	print '[LDR] with name '
	mov eax, [edx]
	call ldr_get_string_by_offset
	call print_str

	jmp $

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
	call ldr_parse_segments

	print 'Loading loom...', 10
    jmp $

str_segment:
db 'SEGMENT', 0

; For debugging purposes
str_data_rw: db 'DATA RW', 0
str_data_ro: db 'DATA RO', 0
str_code_rx: db 'CODE RX', 0
str_stack_rw: db 'STACK RW', 0

loom_base: dd 0

loom_offset: dd 0

; TODO make struct definitions for this
;
;            in memory offset,
;            |  in memory size
;            |  |  on disk offset
;            |  |  |  on disk size
;            |  |  |  |
data_rw:  dd 0, 0, 0, 0, str_data_rw
data_ro:  dd 0, 0, 0, 0, str_data_ro
code_rx:  dd 0, 0, 0, 0, str_code_rx
stack_rw: dd 0, 0, 0, 0, str_stack_rw
