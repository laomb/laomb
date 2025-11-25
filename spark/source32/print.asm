use32

vga_cursor_x: dd 0
vga_cursor_y: dd 0



nibble_to_ascii32:
	and al, 0xf

	cmp al, 9
	jbe .digit

	add al, 7
.digit:
	add al, '0'
	ret



print_char_pmode:
	pushad

	call vga_putc_pmode
	call print_serial_pmode

.done:
	popad
	ret



print_str_pmode:
	pushad

.next_char:
	lodsb
	test al, al
	jz .done

	cmp al, 10
	jne .normal_char

	mov al, 13
	call print_char_pmode
	
	mov al, 10
	call print_char_pmode
	jmp .next_char

.normal_char:
	call print_char_pmode
	jmp .next_char

.done:
	popad
	ret



print_hex8_pmode:
	pushad

	mov bl, al

	mov al, bl
	shr al, 4
	call nibble_to_ascii32
	call print_char_pmode

	mov al, bl
	call nibble_to_ascii32
	call print_char_pmode

	popad
	ret



print_hex16_pmode:
	pushad

	mov bx, ax

	mov al, bh
	shr al, 4
	call nibble_to_ascii32
	call print_char_pmode

	mov al, bh
	call nibble_to_ascii32
	call print_char_pmode

	mov al, bl
	shr al, 4
	call nibble_to_ascii32
	call print_char_pmode

	mov al, bl
	call nibble_to_ascii32
	call print_char_pmode

	popad
	ret



print_hex32_pmode:
	pushad

	mov ecx, eax 

	mov eax, ecx
	shr eax, 28
	mov al, al
	call nibble_to_ascii32
	call print_char_pmode

	mov eax, ecx
	shr eax, 24
	call nibble_to_ascii32
	call print_char_pmode

	mov eax, ecx
	shr eax, 20
	call nibble_to_ascii32
	call print_char_pmode

	mov eax, ecx
	shr eax, 16
	call nibble_to_ascii32
	call print_char_pmode

	mov eax, ecx
	shr eax, 12
	call nibble_to_ascii32
	call print_char_pmode

	mov eax, ecx
	shr eax, 8
	call nibble_to_ascii32
	call print_char_pmode

	mov eax, ecx
	shr eax, 4
	call nibble_to_ascii32
	call print_char_pmode

	mov eax, ecx
	
	call nibble_to_ascii32
	call print_char_pmode

	popad
	ret



vga_clear_pmode:
	pushad

	mov edi, vga_text_memory
	mov ecx, vga_width * vga_height
	mov ah, 0x7
	mov al, ' '

.clear_loop:
	mov [edi], ax
	add edi, 2
	loop .clear_loop

	xor eax, eax
	mov [vga_cursor_x], eax
	mov [vga_cursor_y], eax

	popad
	ret


; Out: EDI -> base address cursor in VGA memory
vga_get_offset_pmode:
	push eax
	push ebx

	mov eax, [vga_cursor_y]
	mov ebx, vga_width
	mul ebx
	add eax, [vga_cursor_x]
	shl eax, 1

	mov edi, vga_text_memory
	add edi, eax

	pop ebx
	pop eax
	ret



vga_scroll_pmode:
	pushad

	mov eax, [vga_cursor_y]
	cmp eax, vga_height
	jl .no_scroll

	mov esi, vga_text_memory + vga_width * 2
	mov edi, vga_text_memory
	mov ecx, (vga_height - 1) * vga_width
	rep movsw

	mov ecx, vga_width
	mov ah, 0x7
	mov al, ' '
	mov edi, vga_text_memory + (vga_height - 1) * vga_width * 2

.clear_last:
	mov [edi], ax
	add edi, 2
	loop .clear_last

	mov eax, vga_height - 1
	mov [vga_cursor_y], eax

.no_scroll:
	popad
	ret



vga_putc_pmode:
	pushad

	cmp al, 10
	je .newline
	cmp al, 13
	je .carriage

	call vga_get_offset_pmode
	mov ah, 0x7
	mov [edi], ax

	mov eax, [vga_cursor_x]
	inc eax
	cmp eax, vga_width
	jl .store_x

	xor eax, eax
	mov [vga_cursor_x], eax
	mov eax, [vga_cursor_y]
	inc eax
	mov [vga_cursor_y], eax
	jmp .maybe_scroll

.store_x:
	mov [vga_cursor_x], eax
	jmp .done

.newline:
	mov eax, [vga_cursor_y]
	inc eax
	mov [vga_cursor_y], eax
.carriage:
	xor eax, eax
	mov [vga_cursor_x], eax

.maybe_scroll:
	call vga_scroll_pmode

.done:
	popad
	ret
