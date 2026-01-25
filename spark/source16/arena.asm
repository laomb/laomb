
; [in] AX = bytes to allocate
; [out] AX = pointer to allocated memory base
arena_alloc16:
	push bx cx dx

	mov bx, word [arena_used]

	; align the base of the new allocation.
	mov cx, bx
	add cx, 1
	and cx, 0xfffe

	; calculate how many free bytes are left.
	mov dx, heap_limit - heap_base
	sub dx, cx

	; if we are requesting more, oom.
	cmp ax, dx
	ja .oom

	; store back the new number of allocated bytes.
	mov bx, cx
	add cx, ax
	mov word [arena_used], cx

	; return pointer to the aligned base.
	add bx, heap_base
	mov ax, bx
.done:
	pop dx cx bx
	ret

.oom:
	xor ax, ax
	jmp .done

arena_mark16:
	mov ax, word [arena_used]
	ret

arena_rewind16:
	mov word [arena_used], ax
	ret

arena_used: dw 0
