
stack_adjust_offset = 32 ; 6 (regs) * 4 (dword) + 2 (ret addr + caller esi) * 4 (word)
stack_dwords_to_dump = 16
stack_dwords_per_line = 4

panic_pmode:
	push eax
	push ebx
	push ecx
	push edx
	push edi
	push ebp

	mov ebp, esp

	push esi
	mov esi, str_pad
	call print_str_pmode
	pop esi

	call print_str_pmode

	mov al, 13
	call print_char_pmode
	mov al, 10
	call print_char_pmode

	push esi
	mov esi, str_at_csip
	call print_str_pmode
	pop esi

	push cs
	pop ax
	call print_hex16_pmode

	mov al, ':'
	call print_char_pmode

	mov eax, [ebp + 24]
	call print_hex32_pmode

	mov al, ' '
	call print_char_pmode

	mov al, 13
	call print_char_pmode
	mov al, 10
	call print_char_pmode

	print_raw 10, 'EAX: 0x', [ebp + 20], ' EBX: 0x', [ebp + 16],
	print_raw ' ECX: 0x', [ebp + 12], ' EDX: 0x', [ebp + 8], 10
	print_raw 'EDI: 0x', [ebp + 4], ' ESI: 0x', [ebp + 28], 10

	mov ebp, esp
	add ebp, stack_adjust_offset

	print_raw 'SS: 0x', ss, ' SP: 0x', ebp, 10

	cli
	jmp halt

