
stack_adjust_offset = 18 ; 7 (regs+flags) * 2 (word) + 2 (ret addr + caller si) * 2 (word)
stack_words_to_dump = 16
stack_words_per_line = 8



panic_rmode:
	pushf
	push ax
	push bx
	push cx
	push dx
	push di
	push bp

	mov bp, sp

	push si
	mov si, str_pad
	call print_str_rmode
	pop si

	call print_str_rmode

	mov al, 13
	call print_char_rmode
	mov al, 10
	call print_char_rmode

	push si
	mov si, str_at_csip
	call print_str_rmode
	pop si

	push cs
	pop ax
	call print_hex16_rmode

	mov al, ':'
	call print_char_rmode

	mov ax, [bp + 14]
	call print_hex16_rmode

	mov al, ' '
	call print_char_rmode

	mov ax, [bp + 12]
	call print_flags_rmode

	print_raw 10, 'AX: 0x', [bp + 10], ' BX: 0x', [bp + 8], ' CX: 0x', [bp + 6], ' DX: 0x', [bp + 4], 10
	print_raw 'SI: 0x', [bp + 16], ' DI: 0x', [bp + 2], 10
	print_raw 'DS: 0x', ds, ' ES: 0x', es, ' FS: 0x', fs, ' GS: 0x', gs, 10

	mov bp, sp
	add bp, stack_adjust_offset

	print_raw 'SS: 0x', ss, ' SP: 0x', bp, 10

	mov si, str_stackdump
	call print_str_rmode

	mov cx, stack_words_to_dump
	xor bx, bx
.dump_loop:
	cmp cx, 0
	je .done

	cmp bp, stack_top
	jge .done_limit

	mov al, '0'
	call print_char_rmode
	mov al, 'x'
	call print_char_rmode

	mov ax, [bp]
	call print_hex16_rmode

	mov al, ' '
	call print_char_rmode

	add bp, 2
	inc bx
	dec cx

	cmp bl, stack_words_per_line
	jne .dump_loop

	xor bx, bx
	mov al, 13
	call print_char_rmode
	mov al, 10
	call print_char_rmode

	jmp .dump_loop

.done_limit:
	mov si, str_stackdump_limit_reached
	call print_str_rmode
.done:
	cli
halt:
	hlt
	jmp halt

str_pad: db '> ', 0
str_at_csip: db 'CS:IP=', 0
str_stackdump: db 10, 'Stack dump @ SS:SP', 10, 0
str_stackdump_limit_reached: db 10, '(stack top reached)', 10, 0
