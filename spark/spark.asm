org 0x500
use16

endl = 10

include 'memory_layout.inc'
include 'print.inc'
include 'assert.inc'
include 'panic.inc'

_start:
	mov ax, stack_segment
	mov ss, ax
	
	mov sp, 0x4000

	call serial_init

	mov al, 10
	call print_char_rmode
	mov al, 13
	call print_char_rmode

	call mem_init

	panic '[_start] spark not implemented.'

include 'source/print.asm'
include 'source/serial.asm'
include 'source/memtrack.asm'
include 'source/panic.asm'
include 'source/assert.asm'

late_str_finalize
