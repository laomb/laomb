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

	call mem_init

	print 10, !mem, 10

	panic 'Spark not implemented.'

include 'source/print.asm'
include 'source/serial.asm'
include 'source/memtrack.asm'
include 'source/panic.asm'
include 'source/assert.asm'

late_str_finalize
