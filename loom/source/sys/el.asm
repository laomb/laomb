
EL_0 = 0
EL_1 = 1
EL_2 = 2
EL_3 = 3

; procedure loom$lower_el(new_el: Byte);
loom$lower_el:
	push ebx

	movzx ebx, al

	; check if we are trying to wrongly raise EL. 
	cmp ebx, dword [loom$current_el]
	ja loom$_invalid_el_change

	; check if we are lowering to L1/L2.
	cmp ebx, EL_0
	jne .set_only

.check_shuttle:
	; transition into L0, check if we need to invoke the shuttle.
	cmp dword [shuttle$knot_head], 0
	jz .set_only

	; raise EL to L1 before allowing ISRs to run.
	mov dword [loom$current_el], EL_1
	sti
	call shuttle$dispatch
	cli

	jmp .check_shuttle

.set_only:
	mov dword [loom$current_el], ebx

	pop ebx
	ret

; function loom$raise_el(new_el: Byte): Byte;
loom$raise_el:
	movzx ecx, al
	mov eax, [loom$current_el]

	cmp ecx, eax
	jb loom$_invalid_el_change

	mov [loom$current_el], ecx
	ret

loom$_invalid_el_change:
	; TODO call into debugger.
	jmp $

segment 'DATA', ST_DATA_RW

loom$current_el:
	dd EL_0
