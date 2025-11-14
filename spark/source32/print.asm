use32

nibble_to_ascii32:
	and al, 0xf

	cmp al, 9
	jbe .digit

	add al, 7
.digit:
	add al, '0'
	ret



print_char_pmode:
	jmp print_serial_pmode



print_str_pmode:
	pushad

.next_char:
	lodsb
	test al, al
	jz .done

	cmp al, 10
	jne .normal_char

	mov al, 13
	call print_serial_pmode
	
	mov al, 10
	call print_serial_pmode
	jmp .next_char

.normal_char:
	call print_serial_pmode
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
