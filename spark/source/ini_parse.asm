; Section:
; [ 1B name_len | 2B entry_count | name_bytes... | entries... ]

; Entry:
; [ 1B key_len | 1B type (1=number,2=string) | (1B str_len if string) | key_bytes... | value_payload... ]

; Number payload: 4B (lo word, hi word)
; String payload: <str_len> bytes


; In: SI = source string, BH = char to eat if available
; Out: CF=1 -> Char eaten
;      CF=0 -> Char not found
eat_ch:
	push ax

	mov al, [si]
	cmp al, bh
	jnz .not

	inc si

	pop ax

	stc
	ret

.not:
	pop ax
	
	clc
	ret


; In: SI = source string
; Out: BX = number of chars skipped, SI = advanced pointer
count_identifier:
	xor bx, bx
	push ax
	
.loop:
	cmp byte [si], 0
	je .done

	mov al, byte [si]
	cmp al, 'A'
	jb .check_underscore
	cmp al, 'Z'
	jbe .accept

.check_lower:
	cmp al, 'a'
	jb .check_underscore
	cmp al, 'z'
	jbe .accept

.check_digit:
	cmp al, '0'
	jb .check_underscore
	cmp al, '9'
	jbe .accept

.check_underscore:
	cmp al, '_'
	jne .done

.accept:
	inc si
	inc bx

	jmp .loop

.done:
	pop ax
	ret


; In: SI = source string
; Out: BX = number of characters skipped, SI = advanced si
count_number:
	xor bx, bx
	push ax

	mov al, [si]

	cmp al, 0
	je .done

	cmp al, '0'
	jb .done

	cmp al, '9'
	ja .done

	cmp al, '0'
	jne .decimal_loop

	mov al, [si + 1]
	cmp al, 'x'
	je .try_hex

	cmp al, 'X'
	je .try_hex

	jmp .decimal_loop

.try_hex:
	mov al, [si + 2]

	cmp al, 0
	je .consume_single_zero

	cmp al, '0'
	jb .consume_single_zero

	cmp al, '9'
	jbe .begin_hex

	cmp al, 'A'
	jb .check_lo_hex_after_prefix

	cmp al, 'F'
	jbe .begin_hex
.check_lo_hex_after_prefix:
	cmp al, 'a'
	jb .consume_single_zero

	cmp al, 'f'
	ja .consume_single_zero
.begin_hex:
	add si, 2
	add bx, 2

.hex_loop:
	mov al, [si]
	cmp al, 0
	je .done

	cmp al, '0'
	jb .done

	cmp al, '9'
	jbe .accept_hex

	cmp al, 'A'
	jb .check_lo_hex

	cmp al, 'F'
	jbe .accept_hex
.check_lo_hex:
	cmp al, 'a'
	jb .done

	cmp al, 'f'
	ja .done
.accept_hex:
	inc si
	inc bx
	jmp .hex_loop

.consume_single_zero:
	inc si
	inc bx

	jmp .done

.decimal_loop:
	mov al, [si]
	cmp al, 0
	je .done

	cmp al, '0'
	jb .done

	cmp al, '9'
	ja .done
.accept_dec:
	inc si
	inc bx

	jmp .decimal_loop

.done:
	pop ax
	ret


; In: SI = source string
; Out: CF=1 -> [SI] is an identifier char ; CF=0 -> It is not
peek_is_ident:
	push ax
	mov al, [si]
	cmp al, 0
	je .no

	cmp al, 'A'
	jb .check_lower

	cmp al, 'Z'
	jbe .yes
.check_lower:
	cmp al, 'a'
	jb .check_digit

	cmp al, 'z'
	jbe .yes
.check_digit:
	cmp al, '0'
	jb .check_underscore

	cmp al, '9'
	jbe .yes
.check_underscore:
	cmp al, '_'
	je .yes

.no:
	pop ax
	clc
	ret

.yes:
	pop ax
	stc
	ret


; In: SI = source string
; Out: CF=1 -> [SI] is a number ; CF=0 -> It is not
peek_is_num:
	push ax

	mov al, [si]

	cmp al, 0
	je .no

	cmp al, '0'
	jb .no

	cmp al, '9'
	ja .no

.yes:
	pop ax

	stc
	ret

.no:
	pop ax

	clc
	ret


; In: SI = source string
; Out: SI = advanced source string over whitespace
skip_spaces:
	push ax
.ss_loop:
	mov al, [si]
	cmp al, ' '
	je .eat

	cmp al, 9
	jne .out

.eat:
	inc si
	jmp .ss_loop

.out:
	pop ax
	ret


; In: SI = source string
; Out: SI = advanced source string to the end of the line with EOL consumed.
skip_line:
	push ax

.sl_loop:
	mov al, [si]

	cmp al, 0
	je .out

	cmp al, 10
	je .eat1

	cmp al, 13
	je .eat1

	inc si
	jmp .sl_loop

.eat1:
	inc si
	
	mov al, [si - 1]
	cmp al, 13
	jne .out
	
	mov al, [si]
	cmp al, 10
	jne .out

	inc si
.out:
	pop ax

	ret


; In: SI = source string
; Out: SI = source string with EOL consumed.
eat_eol:
	push ax

	mov al, [si]
	cmp al, 13
	jne .chk_lf

	inc si

	cmp byte [si], 10
	jne .done

	inc si
	jmp .done

.chk_lf:
	cmp al, 10
	jne .done

	inc si
.done:
	pop ax
	ret


; In: SI = source string
; Out: CF=0 -> AX = number of bytes required to store parsed state
; 	   CF=1 -> error
ini_parse_stage1:
	mov byte [build_error_stage1], 0

	push bp si di dx cx bx
	
	xor di, di
	xor dx, dx
	xor cx, cx

.main_loop:
	cmp byte [si], 0
	je .done_all

	call skip_spaces

	cmp byte [si], ';'
	jne .check_section
	
	call skip_line

	jmp .main_loop

.ml_eat_blank:
	call skip_line
	jmp .main_loop

.check_section:
	cmp byte [si], 13
	je .ml_eat_blank
	cmp byte [si], 10
	je .ml_eat_blank

	push si

	cmp byte [si], '['
	jne .maybe_kv

	inc si	
	call count_identifier
	mov ax, bx
	
	call skip_spaces
	mov bh, ']'
	call eat_ch
	jnc .bad_section_line

	call skip_spaces

	cmp byte [si], ';'
	jne .consume_eol_opt

	call skip_line

	jmp .after_section

.bad_section_line:
	mov bx, si
	pop si
	sub bx, si

	print_raw "Broken section header '", !cstr(si | bx), "'", 10
	mov byte [build_error_stage1], 1

	call skip_line

	jmp .main_loop

.consume_eol_opt:
	call eat_eol
.after_section:
	add sp, 2

	cmp ax, 1
	jb .main_loop

	add di, 3 ; str_len(1) + payload_len(2)
	add di, ax ; name bytes

	mov cx, 1
	xor dx, dx
	jmp .main_loop

.maybe_kv:
	pop si

	cmp cx, 0
	je .skip_unknown_line

	call count_identifier
	mov bp, bx
	
	cmp bp, 1
	jb .kv_fail_restore

	call skip_spaces

	mov bh, '='
	call eat_ch
	jnc .kv_fail_restore

	call skip_spaces

	mov al, [si]
	cmp al, '"'
	je .parse_quoted_string

	call peek_is_num
	jc .parse_number

	call peek_is_ident
	jc .parse_bare_ident

	jmp .kv_fail_restore

.parse_quoted_string:
	inc si
	xor bx, bx
.qs_loop:
	mov al, [si]
	
	cmp al, 0
	je .qs_end

	cmp al, 13
	je .qs_end

	cmp al, 10
	je .qs_end

	cmp al, '"'
	je .qs_close

	inc si
	inc bx
	jmp .qs_loop

.qs_close:
	inc si
.qs_end:
	call skip_spaces

	mov al, [si]

	cmp al, ';'
	jne .qs_eat_eol

	call skip_line

	jmp .qs_commit

.qs_eat_eol:
	call eat_eol

.qs_commit:
	add di, bp ; key bytes
	add di, 3 ; key_len(1) + type(1=2 for string) + value_len(1)
	add di, bx ; payload
	inc dx

	jmp .main_loop

.parse_number:
	call count_number
	cmp bx, 1
	jb .kv_fail_restore

	call skip_spaces

	mov al, [si]
	cmp al, ';'
	jne .num_eat_eol
	
	call skip_line

	jmp .num_commit

.num_eat_eol:
	call eat_eol
.num_commit:
	add di, bp ; key bytes
	add di, 2 ; key_len(1) + type(1)
	add di, 4 ; two words
	inc dx

	jmp .main_loop

.parse_bare_ident:
	call count_identifier

	call skip_spaces
	
	mov al, [si]

	cmp al, ';'
	jne .bi_eat_eol
	
	call skip_line
	
	jmp .bi_commit

.bi_eat_eol:
	call eat_eol
.bi_commit:
	add di, bp ; key_len
	add di, 3 ; header(3)
	add di, bx ; value_len
	inc dx

	jmp .main_loop

.kv_fail_restore:
	print_raw 'Failed to parse a valid entry', 10
	mov byte [build_error_stage1], 1

	call skip_line

	jmp .main_loop

.skip_unknown_line:
	call skip_line
	jmp .main_loop

.done_all:
	mov ax, di
	clc

	cmp byte [build_error_stage1], 0
	je .done
	stc

.done:
	pop bx cx dx di si bp
	ret


; In: BX = bytes to copy, DS:SI = source, ES:DI = dest
memcpy_bx:
	push ax cx

	mov cx, bx
	jcxz .out

.rep:
	lodsb
	stosb

	loop .rep
.out:
	pop cx ax
	ret

; In: AX = X
; Out: AX = min(AX, 255)
clamp_ax_255:
	cmp ax, 255
	jbe .ok

	mov ax, 255
.ok:
	ret


; In: SI = number literal
; Out: CF=0 -> DX:AX = value (unsigned 32 bit), SI = advanced pointer past digits
; 	   CF=1 -> error
parse_number_to_u32:
	push bx cx di

	push si

	xor dx, dx
	xor ax, ax

	mov bl, byte [si]

	cmp bl, '0'
	jb .fail_restore

	cmp bl, '9'
	ja .fail_restore

	cmp bl, '0'
	jne .dec

	mov bl, byte [si + 1]
	cmp bl, 'x'
	je .hex

	cmp bl, 'X'
	je .hex

.dec:
	xor cx, cx
.dec_loop:
	mov bl, byte [si]
	
	cmp bl, '0'
	jb .dec_done

	cmp bl, '9'
	ja .dec_done

	mov di, ax
	mov bx, dx

	shl ax, 1
	rcl dx, 1
	jc .fail_restore

	repeat 3
		shl di, 1
		rcl bx, 1
		jc .fail_restore
	end repeat

	add ax, di
	adc dx, bx
	jc .fail_restore

	mov bl, byte [si]
	sub bl, '0'
	mov bh, 0
	add ax, bx
	adc dx, 0
	jc .fail_restore

	inc si
	inc cx
	jmp .dec_loop

.dec_done:
	test cx, cx
	jz .fail_restore
	clc

	add sp, 2
	jmp .out

.hex:
	add si, 2
	xor cx, cx

	mov bl, [si]

	cmp bl, 0
	je .hex_zero_ok

	cmp bl, ' '
	je .hex_zero_ok

	cmp bl, 9
	je .hex_zero_ok

	cmp bl, ';'
	je .hex_zero_ok

	cmp bl, 10
	je .hex_zero_ok

	cmp bl, 13
	je .hex_zero_ok
.hex_loop:
	mov bl, byte [si]

	cmp bl, 0
	je .hex_done

	cmp bl, '0'
	jb .hex_done

	cmp bl, '9'
	jbe .hex_digit

	cmp bl, 'A'
	jb .hex_check_lo

	cmp bl, 'F'
	jbe .hex_upper

.hex_check_lo:
	cmp bl, 'a'
	jb .hex_done

	cmp bl, 'f'
	ja .hex_done

	sub bl, 'a' - 10
	jmp .have_nib

.hex_upper:
	sub bl, 'A' - 10
	jmp .have_nib

.hex_digit:
	sub bl, '0'
.have_nib:
	repeat 4
		shl ax, 1
		rcl dx, 1
		jc .fail_restore
	end repeat

	xor bh, bh
	add ax, bx
	adc dx, 0
	jc .fail_restore

	inc si
	inc cx

	jmp .hex_loop

.hex_done:
	test cx, cx
	jz .fail_restore
	clc

	add sp, 2
	jmp .out

.hex_zero_ok:
	xor ax, ax
	xor dx, dx

	clc
	add sp, 2
	jmp .out

.fail_restore:
	pop si
	stc
.out:
	pop di cx bx
	ret


; In: SI = NUL-terminated source pointer
; Out: CF=0 -> AX = handle to parsed database
;	   CF=1 -> error 
ini_parser_build:
	push bx cx dx si di bp es

	mov byte [build_error], 0

	push si
	call ini_parse_stage1
	pop si
	jnc .ini_parse_ok

	jmp .fatal_error

.ini_parse_ok:
	mov cx, ax

	test cx, cx
	jnz .non_zero
	jmp .fatal_error

.non_zero:

	call mem_alloc
	jnc .alloc_ok

	jmp .fail_alloc

.alloc_ok:
	mov di, ax
	mov word [out_handle], ax

	push ds
	pop es

	xor cx, cx
	xor dx, dx

	mov word [sec_count_ptr], 0
.main:
	cmp byte [si], 0
	je .eof

	call skip_spaces

	cmp byte [si], ';'
	jne .chk_sec

	call skip_line

	jmp .main

.chk_sec:
	cmp byte [si], '['
	jne .maybe_kv

	cmp cx, 0
	je .start_sec

	push ax
	push di

	mov di, word [sec_count_ptr]
	mov ax, dx
	stosw

	pop di
	pop ax
.start_sec:
	inc si
	mov bp, si

	call count_identifier

	mov ax, bx
	call clamp_ax_255

	cmp bx, 1
	jae .have_name

	mov byte [build_error], 1

	call skip_spaces
	
	mov bh, ']'
	call eat_ch
	
	call skip_line

	jmp .main

.have_name:

	call skip_spaces

	mov bh, ']'
	call eat_ch
	jnc .bad_sec_line

	call skip_spaces

	cmp byte [si], ';'
	jne .sec_eol

	call skip_line

	jmp .emit_sec

.sec_eol:
	call eat_eol
.emit_sec:
	push ax
	stosb

	mov word [sec_count_ptr], di

	xor ax, ax
	stosw

	pop ax
	push si

	mov si, bp
	mov bx, ax
	call memcpy_bx

	pop si

	mov cx, 1
	xor dx, dx
	jmp .main

.bad_sec_line:
	mov byte [build_error], 1
	call skip_line
	jmp .main

.maybe_kv:
	cmp cx, 0
	je .skip_line

	mov bp, si

	call count_identifier
	mov ax, bx

	cmp ax, 1
	jb .kv_fail_line

	mov word [key_ptr], bp

	call skip_spaces

	mov bh, '='
	call eat_ch
	jnc .kv_fail_line

	call skip_spaces

	mov al, byte [si]
	cmp al, '"'
	je .val_is_string_quoted

	call peek_is_num
	jc .val_is_number

	call peek_is_ident
	jc .val_is_string_ident

	jmp .kv_fail_line

.val_is_string_quoted:
	lea bp, [si + 1]
	mov word [val_ptr], bp

	xor bx, bx
.vq_scan:
	mov al, [bp]
	
	cmp al, 0
	je .vq_done

	cmp al, 13
	je .vq_done

	cmp al, 10
	je .vq_done

	cmp al, '"'
	je .vq_close

	inc bp
	inc bx

	jmp .vq_scan

.vq_close:
	lea si, [bp + 1]
.vq_done:
	mov ax, [val_ptr]
	dec ax

	cmp si, ax
	jne .vq_have_si

	mov si, bp
.vq_have_si:
	mov [val_len], bx
	mov byte [val_type], 2

	call skip_spaces

	cmp byte [si], ';'
	jne .eol

	call skip_line

	jmp .emit_entry

.val_is_number:
	call parse_number_to_u32
	jc .kv_fail_line

	mov [num_lo], ax
	mov [num_hi], dx
	mov byte [val_type], 1

	call skip_spaces

	cmp byte [si], ';'
	jne .eol

	call skip_line

	jmp .emit_entry

.eol:
	call eat_eol
	jmp .emit_entry

.val_is_string_ident:
	mov bp, si

	call count_identifier

	mov [val_ptr], bp
	mov [val_len], bx
	mov byte [val_type], 2

	call skip_spaces

	cmp byte [si], ';'
	jne .eol

	call skip_line

	jmp .emit_entry

.emit_entry:
	push si

	mov si, [key_ptr]

	call count_identifier
	mov ax, bx

	call clamp_ax_255
	stosb
	mov [key_len_clamped], ax

	mov al, [val_type]
	stosb

	cmp al, 2
	jne .no_len_byte

	mov ax, [val_len]
	call clamp_ax_255
	stosb
.no_len_byte:
	push si

	mov si, [key_ptr]
	mov bx, [key_len_clamped]
	call memcpy_bx

	pop si

	mov al, [val_type]
	cmp al, 1
	je .emit_number

	push si

	mov si, [val_ptr]
	mov ax, [val_len]
	call clamp_ax_255
	mov bx, ax
	call memcpy_bx

	pop si

	jmp .entry_done

.emit_number:
	mov ax, [num_lo]
	stosw
	mov ax, [num_hi]
	stosw

.entry_done:
	inc dx
	pop si
	jmp .main

.kv_fail_line:
	mov byte [build_error], 1
	call skip_line
	jmp .main

.skip_line:
	call skip_line
	jmp .main

.eof:
	cmp cx, 0
	je .success

	push ax
	push di

	mov di, [sec_count_ptr]
	mov ax, dx
	stosw

	pop di
	pop ax

.success:
	mov ax, word [out_handle]
	clc
.out:
	pop es bp di si dx cx bx
	ret

.fail_alloc:
.fatal_error:
	xor ax, ax
	stc
	jmp .out


; In:  DS:SI = cstr
; Out: CX = length (bytes), SI preserved
cstr_len:
	push si
	xor cx, cx
.len_loop:
	lodsb
	test al, al
	jz .done
	inc cx
	jmp .len_loop
.done:
	pop si
	ret


; In:  DS:SI = bufA, ES:DI = bufB, CX = length
; Out: ZF=1 equal, ZF=0 different
memcmp_cx:
	push si di ax cx
	jcxz .eq
.rep:
	lodsb
	scasb
	jne .ne
	loop .rep
.eq:
	pop cx ax di si
	ret
.ne:
	pop cx ax di si
	ret


; In: AX = pointer to start of section
; Out: AX = pointer to the next section
skip_entries:
	push di cx dx

	mov di, ax
	movzx cx, byte [di]
	add ax, 3
	add ax, cx

	mov cx, word [di + 1]
	mov di, ax
.skip_entries_loop:
	movzx dx, byte [di]
	add ax, dx
	inc ax
	
	movzx dx, byte [di + 1]
	cmp dx, 1
	je .number
	cmp dx, 2
	je .string

	stc
	jmp .out

.number:
	add ax, 5
	jmp .finalize

.string:
	movzx dx, byte [di + 2]
	add ax, dx
	inc ax

.finalize:
	mov di, ax
	dec cx

	jcxz .done

	jmp .skip_entries_loop
.done:
	clc
.out:
	pop dx cx di
	ret 

; In:  AX = handle, DS:SI = section cstr, DS:DI = key cstr
; Out: CF=0 -> BX=ptr to string bytes in DB, CX=len
;      CF=1 -> AH=1 not found, AH=2 wrong type
query_string:
	push ax dx bp si di es

	push ds
    pop es

	push di
.find_section:
	mov di, ax

	movzx cx, byte [di]
	lea di, [di + 3]
	call memcmp_cx
	je .found_section

	call skip_entries
	jc .se_fail

	jmp .find_section

.found_section:
	add ax, cx
	add ax, 3

.find_entry:
	mov si, ax
	movzx dx, byte [si + 1]

	cmp dx, 1
	je .skip_number
	cmp dx, 2
	jne .invalid

	movzx cx, byte [si]
	lea si, [si + 3]
	pop di
	call memcmp_cx
	je .found_entry
	push di

	mov si, ax

	movzx cx, byte [si]
	add ax, 3
	add ax, cx

	movzx cx, byte [si + 2]
	add ax, cx

	jmp .find_entry

.skip_number:
	movzx cx, byte [si]
	add ax, cx
	add ax, 6

	jmp .find_entry

.found_entry:
	add si, cx
	mov di, ax

	movzx cx, byte [di + 2]
	mov bx, si

	clc
.qs_out:
	pop es di si bp dx ax
	ret

.invalid:
	print '[query_string] found invalid entry!', 10
	stc
	jmp .qs_out

.se_fail:
	print '[query_string] failed to skip not-queried section', 10
	stc
	jmp .qs_out


; In:  AX = handle, DS:SI = section cstr, DS:DI = key cstr
; Out: CF=0 -> DX:AX = value (unsigned 32 bits)
;      CF=1 -> AH=1 not found, AH=2 wrong type
query_number:
	push cx bx bp si di es

	push ds
    pop es

	push di
.find_section:
	mov di, ax

	movzx cx, byte [di]
	lea di, [di + 3]
	call memcmp_cx
	je .found_section

	call skip_entries
	jc .se_fail

	jmp .find_section

.found_section:
	add ax, cx
	add ax, 3

.find_entry:
	mov si, ax
	movzx dx, byte [si + 1]

    cmp dx, 2
	je .skip_string
	cmp dx, 1
	jne .invalid

	movzx cx, byte [si]
	lea si, [si + 2]
	pop di
	call memcmp_cx
	je .found_entry
	push di

	mov si, ax

	movzx cx, byte [si]
	add ax, 6
	add ax, cx

	jmp .find_entry

.skip_string:
	movzx cx, byte [si]
	add ax, cx
	movzx cx, byte [si + 2]
	add ax, cx
	add ax, 3

	jmp .find_entry

.found_entry:
	add si, cx

	mov ax, word [si]
	mov dx, word [si + 2]

	clc
.qs_out:
	pop es di si bp bx cx
	ret

.invalid:
	print '[query_number] found invalid entry!', 10
	stc
	jmp .qs_out

.se_fail:
	print '[query_number] failed to skip not-queried section', 10
	stc
	jmp .qs_out

build_error_stage1: db 0
build_error: db 0
sec_count_ptr: dw 0
key_len_clamped: dw 0
out_handle: dw 0

key_ptr: dw 0
val_ptr: dw 0
val_len: dw 0
val_type: db 0
num_lo: dw 0
num_hi: dw 0
