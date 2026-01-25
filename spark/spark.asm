org 0x500

include 'memory_layout.asm'
include 'dbg_print.asm'

_start:
	mov ax, stack_segment

	mov ss, ax
	mov sp, stack_top

	call serial_init

	mov ax, 0xDEAD
	mov bx, 0xBEEF

	print "Hello World, ax = ", ax, " bx = ", bx, 10

	jmp $

include 'source16/print.asm'
include 'source16/serial.asm'
