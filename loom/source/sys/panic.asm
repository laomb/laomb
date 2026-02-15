
macro panic msg*
	local lbl
	postpone
		segment 'DATA', ST_DATA_RW
		lbl: db "PANIC: ", msg, 0
	end postpone

	lea eax, [lbl]
	call panic$trigger
end macro

segment 'TEXT', ST_CODE_XO

; procedure panic$common(frame_ptr: ^InterruptFrame, msg_ptr: PAnsiChar);
panic$common:
	mov ebp, eax

	push edx
	mov al, EL_3
	call loom$raise_el

	mov eax, VGA_TEXT_COLOR_WHITE or VGA_TEXT_BACKGROUND_BLUE
	call vga$set_color
	call vga$clear
	pop edx

	print "================ SYSTEM HALT ================\n"

	test edx, edx
	jnz .has_msg

	lea edx, [panic$msg_default]
.has_msg:
	print "{s}\n", edx

	print "Vector: 0x{x}  Error Code: 0x{x}\n", \
		[ebp + InterruptFrame.vector], [ebp + InterruptFrame.errcode]

	print "=============================================\n"

	print "EAX: 0x{x}  EBX: 0x{x}  ECX: 0x{x}  EDX: 0x{x}\n", \
		[ebp + InterruptFrame.s_eax], [ebp + InterruptFrame.s_ebx], \
		[ebp + InterruptFrame.s_ecx], [ebp + InterruptFrame.s_edx]

	print "ESI: 0x{x}  EDI: 0x{x}  EBP: 0x{x}  ESP: 0x{x}\n", \
		[ebp + InterruptFrame.s_esi], [ebp + InterruptFrame.s_edi], \
		[ebp + InterruptFrame.s_ebp], [ebp + InterruptFrame.s_esp]

	print "CS:  0x{x}  DS:  0x{x}  ES:  0x{x}\n", \
		[ebp + InterruptFrame.s_cs], [ebp + InterruptFrame.s_ds], [ebp + InterruptFrame.s_es]
	
	print "FS:  0x{x}  GS:  0x{x}  SS:  0x{x}\n", \
		[ebp + InterruptFrame.s_fs], [ebp + InterruptFrame.s_gs], ss

	mov eax, cr0
	print "CR0: 0x{x}  ", eax
	mov eax, cr2
	print "CR2: 0x{x}  ", eax
	mov eax, cr3
	print "CR3: 0x{x}\n", eax

	print "EIP: 0x{x}  EFLAGS: 0x{x}\n", \
		[ebp + InterruptFrame.s_eip], [ebp + InterruptFrame.s_eflags]

	print "\nStack Dump:\n"
	mov esi, [ebp + InterruptFrame.s_esp]
	mov ecx, 8
.stack_dump:
	cmp esi, LBF.stack_size 
	jae .stack_done

	print "0x{x}: 0x{x}\n", esi, [ss:esi]
	add esi, dword
	dec ecx
	jnz .stack_dump

.stack_done:
	print "\nSystem Halted."

	cli
.halt:
	hlt
	jmp .halt

; procedure panic$trigger(msg_ptr: PAnsiChar);
panic$trigger:
	pop edx

	pushfd
	push cs
	push edx
	push dword 0
	push dword -1

	pushad
	push ds es fs gs
	push dword [loom$current_el]

	mov edx, dword [esp + InterruptFrame.s_eax]
	mov eax, esp

	jmp panic$common

segment 'DATA', ST_DATA_RW

panic$msg_default db "Unhandled Exception", 0

panic$exception_names:
	dd .e0, .e1, .e2, .e3, .e4, .e5, .e6, .e7
	dd .e8, .e9, .e10, .e11, .e12, .e13, .e14, .er
	dd .e16, .e17, .e18, .er, .er, .er, .er, .er
	dd .er, .er, .er, .er, .er, .er, .er, .er

.e0: db "#DE Divide Error", 0
.e1: db "#DB Debug", 0
.e2: db "Non-Maskable Interrupt", 0
.e3: db "#BP Breakpoint", 0
.e4: db "#OF Overflow", 0
.e5: db "#BR BOUND Range Exceeded", 0
.e6: db "#UD Invalid Opcode", 0
.e7: db "#NM Device Not Available", 0
.e8: db "#DF Double Fault", 0
.e9: db "Coprocessor Segment Overrun", 0
.e10: db "#TS Invalid TSS", 0
.e11: db "#NP Segment Not Present", 0
.e12: db "#SS Stack-Segment Fault", 0
.e13: db "#GP General Protection Fault", 0
.e14: db "#PF Page Fault", 0
.e16: db "#MF x87 FPU Floating-Point Error", 0
.e17: db "#AC Alignment Check", 0
.e18: db "#MC Machine Check", 0
.er: db "Reserved", 0
