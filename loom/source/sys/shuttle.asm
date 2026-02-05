
struct Knot
	handler dd ?
	context dd ?
	
	next dd ?
end struct

segment 'TEXT', ST_CODE_XO

; procedure shuttle$dispatch();
shuttle$dispatch:
	push ebx esi edi
.drain_loop:
	; steal the stack.
	xor eax, eax
	lock xchg eax, dword [shuttle$knot_head]

	test eax, eax
	jz .done

	; start with prev as null.
	xor edx, edx
.reverse_loop:
	; if current is null we are done.
	test eax, eax
	jz .reverse_done

	; save the old next pointer.
	mov ecx, [eax + Knot.next]

	; link the current into the previous.
	mov [eax + Knot.next], edx

	; move previous to current and current to next.
	mov edx, eax
	mov eax, ecx

	jmp .reverse_loop

.reverse_done:
	mov eax, edx
.process_batch:
	mov esi, eax

	; load the knot data.
	mov ebx, [esi + Knot.handler]
	mov ecx, [esi + Knot.context]
	mov edi, [esi + Knot.next]

	; call the handler.
	mov eax, ecx
	call ebx

	; move to the next handler if there is.
	mov eax, edi
	test eax, eax
	jnz .process_batch

	jmp .drain_loop

.done:
	pop edi esi ebx
	ret

; procedure shuttle$tie(knot: ^Knot);
shuttle$tie:
	mov edx, eax
.retry:
	mov eax, dword [shuttle$knot_head]
	mov [edx + Knot.next], eax
	lock cmpxchg [shuttle$knot_head], edx
	jnz .retry

	ret

segment 'DATA', ST_DATA_RW

shuttle$knot_head:
	dd ?
