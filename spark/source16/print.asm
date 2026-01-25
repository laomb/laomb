
macro nibble_to_ascii
	and al, 0xf

	cmp al, 9
	jbe @f

	add al, 7
@@:
	add al, '0'
end macro

print_char16:
	pusha

	call serial_putb16

	mov ah, 0xe
	xor bx, bx
	int 0x10

	popa
	ret

print_str16:
	push ax
.next:
	lodsb

	cmp al, 10
	jne .print

	mov al, 13
	call print_char16
	mov al, 10
.print:
	call print_char16
	loop .next

	pop ax
	ret

print_hex8_16:
	push ax bx

	mov bl, al

	shr al, 4
	nibble_to_ascii
	call print_char16

	mov al, bl
	nibble_to_ascii
	call print_char16

	pop bx ax
	ret

print_hex16_16:
	push ax bx

	mov bx, ax

	shr ax, 12
	nibble_to_ascii
	call print_char16

	mov ax, bx
	shr ax, 8
	nibble_to_ascii
	call print_char16

	mov ax, bx
	shr ax, 4
	nibble_to_ascii
	call print_char16

	mov ax, bx
	nibble_to_ascii
	call print_char16

	pop bx ax
	ret
