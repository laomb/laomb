
MAX_SINKS = 4

segment 'TEXT', ST_CODE_XO

; function llog$register_sink(handler: *fn(sz: PAnsiChar)): CF;
llog$register_sink:
	push edi ds es

	xchg edx, eax

	; prepare segment for scan.
	mov ax, rel 'DATA'
	mov ds, ax
	mov es, ax

	; prepare operands for scan.
	lea edi, [llog$sinks]
	mov ecx, MAX_SINKS

	; scan for an empty slot.
	xor eax, eax
	repne scasd
	jne .full

	; write the sinker pointer to the found free slot.
	mov dword [edi - 4], edx

	clc
	pop es ds edi
	ret

.full:
	stc
	pop es ds edi
	ret

; procedure llog$msg(text: PAnsiChar);
llog$msg:
	push esi ebx es

	mov dx, rel 'DATA'
	mov es, dx

	; prepare variables for iterating sinker list.
	lea esi, [es:llog$sinks]
	mov ebx, MAX_SINKS
.loop:
	; load the sinker function pointer.
	mov ecx, dword [es:esi]
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

	pop es ebx esi
	ret

; procedure llog$hex(value: Cardinal, width: Cardinal);
llog$hex:
	push edi ebx ds

	; allow accessing the stack buffer via DS.
	push ss
	pop ds

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

	pop ds ebx edi
	ret

; procedure llog$dec(value: Cardinal);
llog$dec:
	push ebx esi edi ds

	; allow accessing the stack buffer via DS.
	push ss
	pop ds

	; allocate a buffer on the stack.
	sub esp, 16

	; calculate a pointer to the end of the string and add a null terminator.
	lea edi, [esp + 15]
	mov byte [edi], 0

	; base of number.
	mov ebx, 10
.convert:
	dec edi
	xor edx, edx
	div ebx

	; conver the remainder to ascii and store in the buffer.
	add dl, '0'
	mov byte [edi], dl

	; if quotient is 0, we are done
	test eax, eax
	jnz .convert

	; dispatch the message.
	mov eax, edi
	call llog$msg

	add esp, 16
	pop ds edi esi ebx
	ret

segment 'DATA', ST_DATA_RW

llog$sinks:
	dd MAX_SINKS dup(0)
