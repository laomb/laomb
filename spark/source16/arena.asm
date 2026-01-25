
arena_alloc16:
	push bx cx dx

	mov bx, word [arena_used]

	mov cx, bx
	add cx, 1
	and cx, 0xfffe
	
	mov dx, heap_limit - heap_base
	sub dx, cx

	cmp ax, dx
	ja .oom

	mov bx, cx
	add cx, ax
	mov word [arena_used], cx

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
