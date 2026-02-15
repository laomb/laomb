
IDT_ATTR_PRESENT = 0x80
IDT_ATTR_DPL0 = 0x0
IDT_ATTR_INT32 = 0xe
IDT_ATTR_DEFAULT = IDT_ATTR_PRESENT or IDT_ATTR_DPL0 or IDT_ATTR_INT32

struct IdtEntry
	offset_low dw ?
	selector dw ?
	zero db ?
	type_attr db ?
	offset_high dw ?
end struct

struct InterruptFrame
	current_el dd ?

	s_gs dd ?
	s_fs dd ?
	s_es dd ?
	s_ds dd ?

	s_edi dd ?
	s_esi dd ?
	s_ebp dd ?
	s_esp dd ?
	s_ebx dd ?
	s_edx dd ?
	s_ecx dd ?
	s_eax dd ?

	vector dd ?
	errcode dd ?

	s_eip dd ?
	s_cs dd ?
	s_eflags dd ?

	s_user_esp dd ?
	s_user_ss dd ?
end struct

segment 'TEXT', ST_CODE_XO

; procedure idt$init();
idt$init:
	mov ax, ds
	call gdt$get_base

	; convert pointer to ds base to pointer to idt$table.
	add eax, idt$table

	cpu$PUSH_TABLE_DESCRIPTOR (256 * 8) - 1, eax

	lidt [esp]

	cpu$POP_TABLE_DESCRIPTOR
	ret

; procedure idt$isr_common();
idt$isr_common:
	pushad
	push ds es fs gs

	mov ax, rel 'DATA'
	mov ds, ax
	mov es, ax

	push dword [loom$current_el]

	; raise EL to ISR level.
	mov al, EL_2
	call loom$raise_el

	; get the interrupt handler.
	mov eax, dword [esp + InterruptFrame.vector]
	mov esi, dword [idt$handler_table + eax * dword]

	; pass the context frame as a parameter.
	lea eax, [esp]
	call esi

	; lower back to where we came from to allow shuttle to run.
	mov eax, dword [esp]
	call loom$lower_el

	; skip the EL.
	add esp, 4
	pop gs fs es ds
	popad

	; skip error code and vector number.
	add esp, 8
	iret

; procedure idt$register_handler(vector: Byte, handler: Cardinal);
idt$register_handler:
	movzx eax, al

	; write the handler.
	mov dword [idt$handler_table + eax * dword], edx
	ret

; procedure idt$set_gate_attr(vector: Byte, type_attr: Byte);
idt$set_gate_attr:
	movzx eax, al
	shl eax, 3
	add eax, 5

	mov byte [idt$table + eax], cl
	ret

; procedure idt$exception_handler(frame_ptr: ^InterruptFrame);
idt$exception_handler:
	mov ebx, dword [ss:eax + InterruptFrame.vector]
	lea edx, [panic$msg_default]

	cmp ebx, 32
	jae .dispatch

	mov edx, [panic$exception_names + ebx * dword]
.dispatch:
	jmp panic$common

macro idt$_ISR_NOERR index
	isr_#index:
		push dword 0
		push dword index
		jmp idt$isr_common
end macro

macro idt$_ISR_ERR index
	isr_#index:
		push dword index
		jmp idt$isr_common
end macro

repeat 256 i:0
	if i = 8 | ( i >= 10 & i <= 14 ) | i = 17
		idt$_ISR_ERR i
	else
		idt$_ISR_NOERR i
	end if
end repeat

segment 'DATA', ST_DATA_RW

idt$handler_table:
	dd 256 dup(idt$exception_handler)

idt$table:
	repeat 256 i:0 ; TODO task gate for #DF & #NMI handler.
		dw isr_#i and 0xffff
		dw (LBF_SEG_IDX_TEXT + 1) shl 3 ; TODO ugly hack, what if spark decides to not honor this?
		db 0
		db IDT_ATTR_DEFAULT
		dw isr_#i shr 16
	end repeat
