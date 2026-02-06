
struct PanicContext
	gs dd ?
	fs dd ?
	es dd ?
	ds dd ?

	edi dd ?
	esi dd ?
	ebp dd ?
	esp dd ?
	ebx dd ?
	edx dd ?
	ecx dd ?
	eax dd ?

	eip dd ?
end struct

segment 'TEXT', ST_CODE_XO

macro panic msg*
	local lbl

	postpone
		segment 'DATA', ST_DATA_RW
		lbl:
			db "PANIC: ", msg, 0
	end postpone

	mov eax, lbl
	jmp panic$trigger
end macro

panic$trigger:
	cli

	pushad

	push ds
	push es
	push fs
	push gs

	mov ebp, esp

	mov eax, VGA_TEXT_COLOR_WHITE or VGA_TEXT_BACKGROUND_BLUE
	call vga$set_color

	call vga$clear

	print "================ SYSTEM HALT ================\n"
	print "{s}\n", [ebp + PanicContext.eax]
	print "=============================================\n"

	print "EAX: 0x{x}  EBX: 0x{x}  ECX: 0x{x}  EDX: 0x{x}\n", \
		  [ebp + PanicContext.eax], [ebp + PanicContext.ebx], \
		  [ebp + PanicContext.ecx], [ebp + PanicContext.edx]

	print "ESI: 0x{x}  EDI: 0x{x}  EBP: 0x{x}  ESP: 0x{x}\n", \
		  [ebp + PanicContext.esi], [ebp + PanicContext.edi], \
		  [ebp + PanicContext.ebp], [ebp + PanicContext.esp]

	print "CS:  0x{x}  DS:  0x{x}  ES:  0x{x}\n", \
		  cs, [ebp + PanicContext.ds], [ebp + PanicContext.es]
	print "FS:  0x{x}  GS:  0x{x}  SS:  0x{x}\n", \
		  [ebp + PanicContext.fs], [ebp + PanicContext.gs], ss

	mov eax, cr0
	print "CR0: 0x{x}  ", eax

	mov eax, cr2
	print "CR2: 0x{x}  ", eax

	mov eax, cr3
	print "CR3: 0x{x}\n", eax

	print "EIP: 0x{x}  EFLAGS: ", [ebp + PanicContext.eip]

	pushfd
	pop eax
	print "0x{x}\n", eax

	print "\nStack Dump:\n"

	mov esi, [ebp + PanicContext.esp]
	mov ecx, 5

.stack_dump:
	cmp esi, LBF.stack_size
	jae .skip_stack_dump

	print "0x{x}: ", esi
	print "0x{x}\n", [ss:esi]

	add esi, 4

	dec ecx
	jnz .stack_dump

.skip_stack_dump:
	print "\nSystem Halted.\n"

.hang:
	hlt
	jmp .hang
