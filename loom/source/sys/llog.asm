
MAX_SINKS = 4

segment 'TEXT', ST_CODE_XO

; procedure llog$register_sink(handler: *fn(sz: PAnsiChar));
llog$register_sink:
	push edi es
	xchg edx, eax

	; prepare segment for scan.
	push ds
	pop es

	; prepare operands for scan.
	lea edi, [llog$sinks]
	mov ecx, MAX_SINKS

	; scan for an empty slot.
	xor eax, eax
	repne scasd
	jne .full

	; write the sinker pointer to the found free slot.
	mov [edi - 4], edx

	clc
	pop es edi
	ret

.full:
	stc
	pop es edi
	ret

; procedure llog$msg(text: PAnsiChar);
llog$msg:
	push esi ebx

	; prepare variables for iterating sinker list.
	lea esi, [llog$sinks]
	mov ebx, MAX_SINKS
.loop:
	; load the sinker function pointer.
	mov ecx, [esi]
	test ecx, ecx
	jz .next

	; call the sinker.
	push eax
	call ecx
	pop eax

.next:
	add esi, 4
	dec ebx

	jnz .loop

	pop ebx esi
	ret

; procedure llog$hex(value: Cardinal, width: Cardinal);
llog$hex:
	push edi ebx

	; allocate a buffer on the stack.
	sub esp, 32

	; calculate a pointer to the end of the string and add a null terminator.
	lea edi, [esp + edx]
	mov byte [edi], 0
.loop:
	dec edi

	; extract the lowest nibble.
	mov ecx, eax
	and ecx, 0xf

	; convert it to ascii.
	cmp cl, 9
	jbe .digit

	add cl, 7
.digit:
	add cl, '0'
	mov byte [edi], cl

	; shift to the next nibble.
	shr eax, 4
	dec edx
	jnz .loop

	; dispatch the message.
	mov eax, edi
	call llog$msg

	add esp, 32

	pop ebx edi
	ret

segment 'DATA', ST_DATA_RW

llog$sinks:
	dd MAX_SINKS dup(0)
