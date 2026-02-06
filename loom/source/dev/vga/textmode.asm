
VGA_TEXT_BUFFER_ADDR = 0xb8000
VGA_TEXT_WIDTH = 80
VGA_TEXT_HEIGHT = 25
VGA_TEXT_COLOR_WHITE = 0xf
VGA_TEXT_COLOR_RED = 0xc
VGA_TEXT_BACKGROUND_BLUE = 0x10

VGA_TEXT_FLAG_CURSOR_FOLLOW = 1

struct VgaTextModeState
	cursor_x dd ?
	cursor_y dd ?

	color db ?
	flags db ?
	reserved rb 2
end struct

macro vga$_LOAD_CLEAR_EAX
	; load the same color:space pattern into high and low words of eax.
	mov ah, [vga_text_mode_state.color]
	mov al, ' '
	shl eax, 16

	mov ah, [vga_text_mode_state.color]
	mov al, ' '
end macro

macro vga$ENABLE_CURSOR cursor_start:14, cursor_end:15
	mov eax, cursor_start
	mov edx, cursor_end

	call vga$_enable_cursor
end macro

macro vga$DISABLE_CURSOR
	call vga$_disable_cursor
end macro

segment 'TEXT', ST_CODE_XO

; procedure vga$init();
vga$init:
	push ds

	mov ax, rel 'DATA'
	mov ds, ax

	mov [vga_text_mode_state.cursor_x], 0
	mov [vga_text_mode_state.cursor_y], 0
	mov [vga_text_mode_state.color], VGA_TEXT_COLOR_WHITE
	mov [vga_text_mode_state.flags], VGA_TEXT_FLAG_CURSOR_FOLLOW

	vga$ENABLE_CURSOR
	call vga$_update_hw_cursor

	pop ds
	ret

; procedure vga$write_char(character: Byte);
vga$write_char:
	push ebx edi ds es

	; load a flat segment for accessing VGA memory.
	mm$SET_FLAT es

	mov bx, rel 'DATA'
	mov ds, bx

	cmp al, 0xa
	je .newline

	cmp al, 0xd
	je .cr

	; calculate next address "0xB8000 + ((y * 80) + x) * 2"
	mov ebx, [vga_text_mode_state.cursor_y]
	imul ebx, VGA_TEXT_WIDTH
	add ebx, [vga_text_mode_state.cursor_x]
	shl ebx, 1
	add ebx, VGA_TEXT_BUFFER_ADDR

	; draw character.
	mov ah, [vga_text_mode_state.color]
	mov [es:ebx], ax

	; advance the cursor.
	inc dword [vga_text_mode_state.cursor_x]
	cmp dword [vga_text_mode_state.cursor_x], VGA_TEXT_WIDTH
	jl .done
.newline:
	mov dword [vga_text_mode_state.cursor_x], 0
	inc dword [vga_text_mode_state.cursor_y]

	; check if we have to scroll.
	cmp dword [vga_text_mode_state.cursor_y], VGA_TEXT_HEIGHT
	jl .done

	call vga$_scroll_up
	dec dword [vga_text_mode_state.cursor_y]
	jmp .done

.cr:
	mov dword [vga_text_mode_state.cursor_x], 0
	jmp .done

.done:
	; check if we have to update the hardware cursor.
	test byte [vga_text_mode_state.flags], VGA_TEXT_FLAG_CURSOR_FOLLOW
	jz .skip_hw_update
	call vga$_update_hw_cursor
.skip_hw_update:
	pop es ds edi ebx
	ret

; procedure vga$clear();
vga$clear:
	push ecx edi ds es

	; load a flat segment for accessing VGA memory.
	mm$SET_FLAT es

	mov ax, rel 'DATA'
	mov ds, ax

	cld

	; prepare the pointer to the vga text mode buffer and number of dwords it spans.
	mov edi, VGA_TEXT_BUFFER_ADDR
	mov ecx, (VGA_TEXT_WIDTH * VGA_TEXT_HEIGHT * 2) / dword

	vga$_LOAD_CLEAR_EAX

	rep stosd

	; reset the cursor.
	mov [vga_text_mode_state.cursor_x], 0
	mov [vga_text_mode_state.cursor_y], 0

	; sync the hardware cursor.
	test byte [vga_text_mode_state.flags], VGA_TEXT_FLAG_CURSOR_FOLLOW
	jz .done
	call vga$_update_hw_cursor

.done:
	pop es ds edi ecx
	ret

; packed_color_byte = background << 4 | foreground
;
; procedure vga$clear(packed_color_byte: Byte);
vga$set_color:
	push ds

	mov cx, rel 'DATA'
	mov ds, cx

	mov [vga_text_mode_state.color], al

	pop ds
	ret

; procedure vga$print(str: PAnsiChar);
vga$print:
	push esi

	mov esi, eax
.loop:
	movzx eax, byte [esi]
	test al, al
	jz .end

	call vga$write_char
	inc esi
	jmp .loop

.end:
	pop esi
	ret

; procedure vga$_scroll_up();
vga$_scroll_up:
	push esi edi ds es

	; load a flat segment for accessing VGA memory.
	mm$SET_FLAT es

	; load the same flat segment into ds as movs? moves `ds:esi` to `es:edi`.
	push es
	pop ds

	cld

	; shift lines 1-24 to 0-23.
	mov edi, VGA_TEXT_BUFFER_ADDR
	mov esi, VGA_TEXT_BUFFER_ADDR + (VGA_TEXT_WIDTH * 2)
	mov ecx, (VGA_TEXT_WIDTH * (VGA_TEXT_HEIGHT - 1) * 2) / dword
	rep movsd

	; prepare the pointer and count to the last line, line 24.
	mov edi, VGA_TEXT_BUFFER_ADDR + (VGA_TEXT_WIDTH * (VGA_TEXT_HEIGHT - 1) * 2)
	mov ecx, (VGA_TEXT_WIDTH * 2) / dword

	vga$_LOAD_CLEAR_EAX

	; clear the last line.
	rep stosd

	pop es ds edi esi
	ret

; procedure vga$_update_hw_cursor();
vga$_update_hw_cursor:
	push ebx

	; calculate the linear offset "y * 80 + x"
	mov ebx, [vga_text_mode_state.cursor_y]
	imul ebx, VGA_TEXT_WIDTH
	add ebx, [vga_text_mode_state.cursor_x]

	; configure the VGA controller to recieve the low byte of the offset.
	mov dx, VGA_CRT_INDEX_CONTROL_PORT
	mov al, VGA_CRT_CURSOR_LO
	out dx, al

	; send the low byte.
	mov dx, VGA_CRT_DATA_CONTROL_PORT
	mov al, bl
	out dx, al

	; configure the VGA controller to recieve the high byte of the offset.
	mov dx, VGA_CRT_INDEX_CONTROL_PORT
	mov al, VGA_CRT_CURSOR_HI
	out dx, al

	; send the high byte.
	mov dx, VGA_CRT_DATA_CONTROL_PORT
	mov al, bh
	out dx, al

	pop ebx
	ret

; procedure vga$disable_cursor();
vga$_disable_cursor:
	; configure the VGA controller to recieve the cursor start scanline.
	mov dx, VGA_CRT_INDEX_CONTROL_PORT
	mov al, VGA_CRT_CURSOR_START
	out dx, al

	; read the old scanline, set the disable bit and write back.
	mov dx, VGA_CRT_DATA_CONTROL_PORT
	in al, dx
	or al, 0x20
	out dx, al

	ret

; procedure vga$enable_cursor(cursor_start: Byte, cursor_end: Byte);
vga$_enable_cursor:
	push dx
	push ax

	; configure the VGA controller to recieve the cursor start scanline.
	mov dx, VGA_CRT_INDEX_CONTROL_PORT
	mov al, VGA_CRT_CURSOR_START
	out dx, al

	; send the cursor start scanline.
	mov dx, VGA_CRT_DATA_CONTROL_PORT
	pop ax
	; ensure enable bit is set.
	and al, 0xdf
	out dx, al

	; configure the VGA controller to recieve the cursor end scanline.
	mov dx, VGA_CRT_INDEX_CONTROL_PORT
	mov al, VGA_CRT_CURSOR_END
	out dx, al

	; send the cursor end scanline.
	mov dx, VGA_CRT_DATA_CONTROL_PORT
	pop ax
	out dx, al

	ret

; procedure vga$set_cursor_follow(should_follow: Boolean);
vga$set_cursor_follow:
	push ds

	mov cx, rel 'DATA'
	mov ds, cx

	test al, al
	jz .disable_follow

	or byte [vga_text_mode_state.flags], VGA_TEXT_FLAG_CURSOR_FOLLOW
	call vga$_update_hw_cursor

	pop ds
	ret

.disable_follow:
	and byte [vga_text_mode_state.flags], not VGA_TEXT_FLAG_CURSOR_FOLLOW

	pop ds
	ret

segment 'DATA', ST_DATA_RW
vga_text_mode_state VgaTextModeState
