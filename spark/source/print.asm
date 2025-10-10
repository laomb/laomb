


print_char_rmode:
	pusha

	call print_serial_rmode
	mov ah, 0xe
	xor bx, bx
	int 0x10
	
	popa
	ret



nibble_to_ascii:
	and al, 0xf

	cmp al, 9
	jbe .digit

	add al, 7
.digit:
	add al, '0'
	ret



print_str_rmode:
	push ax
	push bx
.next:
	lodsb
	test al, al
	jz .done

	cmp al, 10
	jne .print

	mov al, 13
	call print_char_rmode
	mov al, 10
.print:
	call print_char_rmode
	jmp .next

.done:
	pop bx
	pop ax
	ret



print_hex8_rmode:
	push ax
	push bx

	mov bl, al

	shr al, 4
	call nibble_to_ascii
	call print_char_rmode

	mov al, bl
	and al, 0xf
	call nibble_to_ascii
	call print_char_rmode

	pop bx
	pop ax
	ret



print_hex16_rmode:
	push ax
	push bx

	mov bx, ax

	shr ax, 12
	call nibble_to_ascii
	call print_char_rmode
	
	mov ax, bx
	shr ax, 8
	call nibble_to_ascii
	call print_char_rmode

	mov ax, bx
	shr ax, 4
	call nibble_to_ascii
	call print_char_rmode
	
	mov ax,bx
	call nibble_to_ascii
	call print_char_rmode

	pop bx
	pop ax
	ret



print_hex32_rmode:
	push eax
	push ebx

	mov ebx, eax

	shr eax, 28
	call nibble_to_ascii
	call print_char_rmode

	mov eax, ebx
	shr eax, 24
	call nibble_to_ascii
	call print_char_rmode

	mov eax, ebx
	shr eax, 20
	call nibble_to_ascii
	call print_char_rmode

	mov eax, ebx
	shr eax, 16
	call nibble_to_ascii
	call print_char_rmode

	mov eax, ebx
	shr eax, 12
	call nibble_to_ascii
	call print_char_rmode

	mov eax, ebx
	shr eax, 8
	call nibble_to_ascii
	call print_char_rmode

	mov eax, ebx
	shr eax, 4
	call nibble_to_ascii
	call print_char_rmode

	mov eax, ebx
	call nibble_to_ascii
	call print_char_rmode

	pop ebx
	pop eax
	ret



print_flags_rmode:
	pusha

	mov bx, ax

	push si
	mov si, str_flags_hdr
	call print_str_rmode
	pop si

macro __emit_flag mask, letter
	local dot, go

	test bx, mask
	jz dot

	mov al, letter
	jmp go

dot:
	mov al, '.'
go:
	call print_char_rmode
	
	mov al, ' '
	call print_char_rmode
end macro

	__emit_flag 1, 'C'
	__emit_flag 4, 'P'
	__emit_flag 16, 'A'
	__emit_flag 64, 'Z'
	__emit_flag 128, 'S'
	__emit_flag 256, 'T'
	__emit_flag 512, 'I'
	__emit_flag 1024, 'D'
	__emit_flag 2048, 'O'

	purge __emit_flag

	mov al, ']'
	call print_char_rmode
	mov al, ' '
	call print_char_rmode

	push ds
	push si
	mov si, str_iopl
	call print_str_rmode
	pop si
	pop ds

	mov ax, bx
	shr ax, 12
	and al, 3
	add al, '0'
	call print_char_rmode

	push ds
	push si
	mov si, str_nt
	call print_str_rmode
	pop si
	pop ds

	test bx, (1 shl 14)
	jz .nt_zero
	
	mov al, '1'
	jmp .nt_done

.nt_zero:
	mov al, '0'
.nt_done:
	call print_char_rmode

	popa
	ret

str_flags_hdr: db 'FLAGS: [',0
str_iopl: db 'IOPL=',0
str_nt: db ' NT=',0
