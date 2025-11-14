
ATTR_BG_BLUE = 0x10
ATTR_FG_WHITE = 0xf
ATTR_FG_YELLOW = 0xe
ATTR_FG_GRAY = 0x8
ATTR_FG_BLACK = 0x0

ATTR_NORMAL = (ATTR_BG_BLUE or ATTR_FG_WHITE)
ATTR_DIM = (ATTR_BG_BLUE or ATTR_FG_GRAY)
ATTR_TITLE = (ATTR_BG_BLUE or ATTR_FG_YELLOW)
ATTR_SELECT = 0x70
ATTR_SHADOW = 0x8

SCR_COLS = 80
SCR_ROWS = 25

BOX_W = 50
BOX_H = 11
BOX_LEFT = ((SCR_COLS - BOX_W) / 2)
BOX_TOP = ((SCR_ROWS - BOX_H) / 2)

ROW_TITLE = (BOX_TOP + 1)
ROW_OPT1 = (BOX_TOP + 4)
ROW_OPT2 = (BOX_TOP + 6)
ROW_HINT = (BOX_TOP + 9)



tui:
	assert "[tui] invalid segments!"

	call check_msdos_present
	mov [msdos_present], al

	call ui_init
	call ui_draw_full

	jmp .render

.loop:
	call ui_getkey

	cmp al, 13
	je .accept

	cmp ah, 0x48
	je .key_up
	cmp ah, 0x50
	je .key_down

	jmp .render

.key_up:
	cmp byte [sel_index], 0
	je .wrap_to_1

	dec byte [sel_index]
	jmp .render

.wrap_to_1:
	mov byte [sel_index], 1
	jmp .render

.key_down:
	cmp byte [sel_index], 1
	je .wrap_to_0

	inc byte [sel_index]
	jmp .render

.wrap_to_0:
	mov byte [sel_index], 0
	jmp .render

.render:
	call ui_draw_options
	jmp .loop

.accept:
	cmp byte [sel_index], 1
	jne .go_continue

	cmp byte [msdos_present], 0
	jne .go_msdos

	mov ah, 0xe
	mov al, 0x7
	int 0x10
	jmp .render

.go_continue:
	jmp continue_boot16

.go_msdos:
	jmp chainboot_msdos



check_msdos_present:
	mov si, msdos_83
	call fat12_find_file
	jc .no

	mov al, 1
	jmp .out

.no:
	xor al, al
.out:
	ret



ui_init:
	pusha

	mov ah, 0xf
	int 0x10
	mov byte [act_page], bh

	mov ax, 0x600
	mov bh, ATTR_NORMAL
	xor cx, cx
	mov dx, (SCR_ROWS - 1) shl 8
	add dl, (SCR_COLS - 1)
	int 0x10

	mov ax, 0x100
	mov cx, 0x2000
	int 0x10

	popa
	ret



ui_draw_full:
	pusha

	mov dh, BOX_TOP
	mov dl, BOX_LEFT
	call set_cursor

	mov bl, ATTR_NORMAL
	mov al, '+'
	call putc_attr

	mov cx, BOX_W - 2
	mov al, '-'
	call rep_putc_attr

	mov al, '+'
	call putc_attr

	mov si, BOX_H - 2
.row_loop:
	inc dh
	mov dl, BOX_LEFT
	call set_cursor

	mov al, '|'
	call putc_attr

	mov cx, BOX_W - 2
	mov al, ' '
	call rep_putc_attr

	mov al, '|'
	call putc_attr

	dec si
	jnz .row_loop

	inc dh
	mov dl, BOX_LEFT
	call set_cursor

	mov al, '+'
	call putc_attr

	mov cx, BOX_W - 2
	mov al, '-'
	call rep_putc_attr

	mov al, '+'
	call putc_attr

	mov dh, ROW_TITLE
	mov dl, BOX_LEFT + 2
	call set_cursor

	mov bl, ATTR_TITLE
	mov si, str_title
	call puts_attr

	mov dh, ROW_HINT
	mov dl, BOX_LEFT + 2
	call set_cursor

	mov bl, ATTR_DIM
	mov si, str_hint
	call puts_attr

	popa
	ret



ui_draw_options:
	pusha

	mov dh, ROW_OPT1
	mov dl, BOX_LEFT + 4
	call set_cursor

	cmp byte [sel_index], 0
	jne .opt0_bg_normal

	mov bl, ATTR_SELECT
	call fill_option_line_attr

	jmp .opt0_label

.opt0_bg_normal:
	mov bl, ATTR_NORMAL
	call fill_option_line_attr
.opt0_label:
	cmp byte [sel_index], 0
	jne .opt0_text_normal

	mov bl, ATTR_SELECT
	jmp .opt0_put

.opt0_text_normal:
	mov bl, ATTR_NORMAL
.opt0_put:
	mov si, str_opt_laomb
	call puts_attr

	mov dh, ROW_OPT2
	mov dl, BOX_LEFT + 4
	call set_cursor

	cmp byte [sel_index], 1
	jne .opt1_bg_normal

	mov bl, ATTR_SELECT
	call fill_option_line_attr

	jmp .opt1_label

.opt1_bg_normal:
	mov bl, ATTR_NORMAL
	call fill_option_line_attr
.opt1_label:
	cmp byte [sel_index], 1
	jne .opt1_maybe_dim

	mov bl, ATTR_SELECT
	jmp .opt1_put_label

.opt1_maybe_dim:
	cmp byte [msdos_present], 0
	jne .opt1_text_normal

	mov bl, ATTR_DIM
	jmp .opt1_put_label

.opt1_text_normal:
	mov bl, ATTR_NORMAL
.opt1_put_label:
	mov si, str_opt_msdos
	call puts_attr

	cmp byte [msdos_present], 0
	jne .done
	
	cmp byte [sel_index], 1
	jne .opt1_nf_dim

	mov bl, ATTR_SELECT
	jmp .opt1_nf_put

.opt1_nf_dim:
	mov bl, ATTR_DIM
.opt1_nf_put:
	mov si, str_notfound
	call puts_attr

.done:
	popa
	ret



draw_highlight_line:
	pusha

	mov ah, 0x3
	mov bh, 0
	int 0x10

	mov bx, 0
	mov bl, ATTR_SELECT
	mov cx, BOX_W - 8
	mov al, ' '
.call_loop:
	call putc_attr

	loop .call_loop
	
	mov dl, BOX_LEFT + 4
	call set_cursor

	popa
	ret



ui_getkey:
	mov ah, 0x10
	int 0x16
	ret



set_cursor:
	mov ah, 0x2
	mov bh, byte [act_page]
	int 0x10
	ret



putc_attr:
	push ax bx cx dx

	mov ah, 0x09
	mov bh, [act_page]
	mov cx, 1
	int 0x10

	mov ah, 0x03
	mov bh, [act_page]
	int 0x10

	inc dl
	cmp dl, SCR_COLS
	jb .set

	xor dl, dl
	inc dh
	cmp dh, SCR_ROWS
	jb .set

	mov dh, SCR_ROWS - 1
.set:
	mov ah, 0x02
	mov bh, [act_page]
	int 0x10

	pop dx cx bx ax
	ret



puts_attr:
	push ax bx cx dx si
.next:
	lodsb

	test al, al
	jz .done

	cmp al, 10
	jne .print

	mov al, 13
	call putc_attr

	mov al, 10
.print:
	call putc_attr
	jmp .next

.done:
	pop si dx cx bx ax
	ret



rep_putc_attr:
	push ax bx cx dx
@@:
	call putc_attr
	loop @b

	pop dx cx bx ax
	ret



fill_option_line_attr:
	pusha
	mov cx, BOX_W - 8
	mov al, ' '
.fill:
	call putc_attr

	loop .fill
	
	mov dl, BOX_LEFT + 4
	call set_cursor

	popa
	ret



msdos_present: db 0
sel_index: db 0
act_page: db 0
msdos_83: db 'MSDOS   HEX'
str_title: db ' LAOMB Boot Menu ', 0
str_hint: db 'Use UP/DOWN to move, Enter to select', 0

str_opt_laomb: db 'Continue booting LAOMB', 0
str_opt_msdos: db 'Chainload MS-DOS', 0
str_notfound: db ' (MSDOS.HEX not found)', 0
