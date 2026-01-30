define LBF_MAGIC 0x0046424C

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

	print 'ecx ', ecx, 10
	print 'edx ', edx, 10

	.loop:

		mov eax, [edx]
		call ldr_get_string_by_offset

		print 'name       -> '
		call print_str

		mov eax, [edx + 4]
		print ' file_off   - ', eax, 10
		mov eax, [edx + 8]
		print ' file_size  - ', eax, 10
		mov eax, [edx + 12]
		print ' mem_size   - ', eax, 10

		add edx, 24
		dec ecx
		jnz .loop

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
	

ldr_load_loom:
	call rng_get
	and eax, 0xFFFF
	print 'PASLR rng: ', eax, 10

	call paslr_find_usable
	print 'PASLR found usable: ', eax, 10

	mov edi, loom_bounce_buffer_flat
	call ldr_check_magic

	mov ebx, str_segment
	call ldr_get_directory_by_name

	print 'segment: ', eax, 10

	mov esi, eax
	call ldr_print_segments


	print 'Loading loom...', 10
    jmp $

str_segment:
db 'SEGMENT', 0
