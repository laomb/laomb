
INIP_TYPE_NULL = 0
INIP_TYPE_IDENT = 1
INIP_TYPE_NUMBER = 2

struct IniEntry
	key 		dw ?
	type 		dw ?

	ident:
	number 		dd ?

	next 		dw ?
end struct

struct IniCategory
	name 		dw ?
	entries 	dw ?
	next 		dw ?
end struct

macro inip_isalpha_
	; backup the character in AH.
	mov ah, al
	
	; convert al to lowercase.
	or al, 0x20

	; x - top < top - bottom fast range check.
	sub al, 0x61
	cmp al, 25
	setbe al

	; if it is underscore, set AH.
	cmp ah, '_'
	sete ah

	; either is a letter, or underscore.
	or al, ah

	xor ah, ah
end macro

macro inip_isspace yes
	; 0x20 => Space
	cmp al, 0x20
	je yes

	; 0x9 => Horizontal Tab
	cmp al, 0x9
	je yes
end macro

; [inout] ES:SI = buffer
inip_skip_ws:
	mov al, byte [es:si]
	inc si

	inip_isspace inip_skip_ws

	dec si
	ret

; [in] ES:SI = buffer
; [out] EAX = parsed number
inip_parse_number:
	push ecx ebx dx

	xor ebx, ebx
	xor ecx, ecx

	; peak for '0x' prefix.
	mov dx, si
	mov al, byte [es:si]
	inc si

	cmp al, '0'
	jne .try_decimal

	; second byte for hex discovery converted to lowercase.
	mov al, byte [es:si]
	inc si

	or al, 0x20
	cmp al, 'x'
	je .loop_hex

	; not hex, restore si and parse decimal.
.try_decimal:
	mov si, dx
.loop_dec:
	mov al, byte [es:si]
	inc si

	; if not in range of 0-9, end parsing.
	sub al, '0'
	cmp al, 9
	ja .done

	movzx ecx, al
	imul ebx, 10
	add ebx, ecx
	jmp .loop_dec

.loop_hex:
	mov al, byte [es:si]
	inc si

	; check for 0-9 digits.
	cmp al, '0'
	jb .done
	cmp al, '9'
	jbe .hex_digit_num

	; check for a-f.
	or al, 0x20
	cmp al, 'a'
	jb .done
	cmp al, 'f'
	ja .done

	; convert 'a'-'f' to 10-15
	sub al, 'a' - 10
	jmp .hex_accumulate

.hex_digit_num:
	sub al, '0'

.hex_accumulate:
	movzx ecx, al
	shl ebx, 4
	add ebx, ecx
	jmp .loop_hex

.done:
	mov eax, ebx
	dec si
	pop dx ebx ecx
	ret

; [in] ES:SI = source
; [out] AX = pointer to string in arena
	; copies string from SI to heap until it hits a delimeter.
inip_extract_string:
	push bx cx di

	mov bx, word [arena_used]

	; calculate the destination address.
	mov di, bx
	add di, heap_base

	; return value is the start of the string.
	mov ax, di
.copy_loop:
	mov cl, byte [es:si]

	test cl, cl
	jz .terminate

	cmp cl, 0xa
	je .terminate

	cmp cl, 0xd
	je .terminate

	cmp cl, '='
	je .terminate

	cmp cl, ';'
	je .terminate

	cmp cl, ']'
	je .terminate

	cmp cl, ' '
	je .terminate

	cmp cl, 0x9
	je .terminate

	mov byte [di], cl
	inc di
	inc si
	jmp .copy_loop

.terminate:
	; ensure null-terminator.
	mov byte [di], 0
	inc di

	; update the allocator arena.
	sub di, heap_base
	mov word [arena_used], di

	pop di cx bx
	ret

; [in] ES:SI = raw ini source
; [out] AX = pointer to root IniCategory
inip_parse:
	push bx cx dx di

	; allocate the initial category.
	mov ax, sizeof.IniCategory
	call arena_alloc16
	test ax, ax
	jz .error_oom

	; initialize the current category pointer.
	mov bx, ax
	mov word [bx + IniCategory.name], 0
	mov word [bx + IniCategory.entries], 0
	mov word [bx + IniCategory.next], 0

	; save the current category pointer.
	push bx
.line_loop:
	call inip_skip_ws

	mov al, byte [es:si]
	test al, al
	jz .finish

	cmp al, ';'
	je .skip_line_comment

	cmp al, 0xa
	je .skip_newline
	cmp al, 0xd
	je .skip_newline

	cmp al, '['
	je .parse_category

	call .parse_entry
	jmp .line_loop

.skip_newline:
	inc si
	jmp .line_loop

.skip_line_comment:
	lodsb

	; newline?
	cmp al, 0xa
	je .line_loop

	; null terminator?
	cmp al, 0
	je .finish

	jmp .skip_line_comment

.finish:
	pop ax
	pop di dx cx bx
	ret

.error_oom:
	xor ax, ax
	pop di dx cx bx
	ret

.parse_category:
	inc si

	; allocate new cateogry.
	mov ax, sizeof.IniCategory
	call arena_alloc16
	test ax, ax
	jz .error_oom

	mov dx, ax

	; link new entry into the old one.
	mov [bx + IniCategory.next], dx
	mov bx, dx

	; zero out the new category.
	mov word [bx + IniCategory.entries], 0
	mov word [bx + IniCategory.next], 0

	call inip_extract_string
	mov [bx + IniCategory.name], ax

	; skip closing bracket if present.
	mov al, byte [es:si]
	cmp al, ']'
	jne .line_loop

	inc si
	jmp .line_loop

.parse_entry:
	push bx

	; allocate an entry.
	mov ax, sizeof.IniEntry
	call arena_alloc16
	test ax, ax
	jz .error_oom_entry

	mov di, ax

	; prepare the entry state and link it into the category. 
	mov cx, word [bx + IniCategory.entries]
	mov word [di + IniEntry.next], cx
	mov word [bx + IniCategory.entries], di

	mov bx, di

	; parse key.
	call inip_extract_string
	mov word [bx + IniEntry.key], ax

	call inip_skip_ws

	; expect = following the key.
	mov al, byte [es:si]
	cmp al, '='
	jne .bad_entry
	inc si

	call inip_skip_ws

	; allow optional quotes.
	mov al, byte [es:si]

	cmp al, "'"
	je .val_quoted

	; if not in number range, fallthrough.
	cmp al, '0'
	jb .val_ident
	cmp al, '9'
	ja .val_ident

	call inip_parse_number
	mov word [bx + IniEntry.type], INIP_TYPE_NUMBER
	mov dword [bx + IniEntry.number], eax
	jmp .entry_done

.val_quoted:
	inc si

	; prepare allocations for the string.
	push cx di
	mov cx, word [arena_used]
	mov di, cx
	add di, heap_base

	; fill in the identifier data.
	movzx eax, di
	mov dword [bx + IniEntry.ident], eax
	mov word [bx + IniEntry.type], INIP_TYPE_IDENT
.quote_loop:
	mov al, byte [es:si]
	test al, al
	jz .quote_finish

	cmp al, "'"
	je .quote_finish

	cmp al, 0xa
	je .quote_finish

	mov byte [di], al
	inc di
	inc si

	jmp .quote_loop

.quote_finish:
	mov byte [di], 0
	inc di

	; update the arena pointer.
	sub di, heap_base
	mov word [arena_used], di

	pop di cx

	; optionally consume closing quote.
	cmp byte [es:si], "'"
	jne .entry_done

	inc si
	jmp .entry_done

.val_ident:
	call inip_extract_string
	movzx eax, ax
	mov dword [bx + IniEntry.ident], eax
	mov word [bx + IniEntry.type], INIP_TYPE_IDENT

	jmp .entry_done

.error_oom_entry:
	pop bx
	pop di
	jmp .error_oom

.entry_done:
	pop bx
	ret

.bad_entry:
	pop bx
	ret

; [in] SI = string 1 pointer
; [in] DI = string 2 pointer
; [out] ZF = 1 if match, 0 if different
inip_strcmp:
	push si di ax
.loop:
	lodsb
	mov ah, byte [di]

	inc di

	; compare the byte.
	cmp al, ah
	jne .diff

	; end of strings?
	test al, al
	jz .match

	jmp .loop

.diff:
	or al, al
	pop ax di si
	ret

.match:
	xor ax, ax
	pop ax di si
	ret

; [in] AX = root category pointer
; [in] DX = name string pointer
; [out] AX = pointer to IniCategory
inip_find_category:
	push bx si di

	mov bx, ax
.loop:
	test bx, bx
	jz .not_found

	; load the category name.
	mov si, word [bx + IniCategory.name]
	mov di, dx

	test si, si
	jz .check_global

	test di, di
	jz .next

	; compare names. 
	call inip_strcmp
	je .found
	jmp .next

.check_global:
	test di, di
	jz .found

.next:
	mov bx, word [bx + IniCategory.next]
	jmp .loop

.found:
	mov ax, bx
	pop di si bx
	ret

.not_found:
	xor ax, ax
	pop di si bx
	ret

; [in] AX = category pointer
; [in] DX = key string pointer
; [out] AX = pointer to IniEntry, or 0 if not found
inip_find_entry:
	push bx si di

	mov di, ax
	mov bx, word [di + IniCategory.entries]
.loop:
	test bx, bx
	jz .not_found

	mov si, word [bx + IniEntry.key]
	mov di, dx
	
	call inip_strcmp
	je .found

	mov bx, word [bx + IniEntry.next]
	jmp .loop

.found:
	mov ax, bx
	pop di si bx
	ret

.not_found:
	xor ax, ax
	pop di si bx
	ret

; [in] AX = entry pointer
; [out] EAX = integer value
; [out] ZF = 0 if successful, 1 if type mismatch or failure
inip_get_int:
	test ax, ax
	jz .fail

	push bx
	mov bx, ax

	cmp word [bx + IniEntry.type], INIP_TYPE_NUMBER
	jne .fail_type

	mov eax, dword [bx + IniEntry.number]

	pop bx
	or sp, sp

	ret

.fail_type:
	pop bx
.fail:
	xor eax, eax
	ret

; [in] AX = entry pointer
; [out] AX = string pointer
; [out] ZF = 0 if successful, 1 if type mismatch or failure
inip_get_str:
	test ax, ax
	jz .fail

	push bx
	mov bx, ax

	cmp word [bx + IniEntry.type], INIP_TYPE_IDENT
	jne .fail_type

	mov ax, word [bx + IniEntry.ident]

	pop bx
	or sp, sp

	ret

.fail_type:
	pop bx
.fail:
	xor ax, ax
	ret
