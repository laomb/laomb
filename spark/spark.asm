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
	call blk_init

	call blk_print

	xor si, si
	mov dx, 1
	mov bx, 0x7e00
	call volume_read

	print 'Boot sector: ', 10
.print_loop:
	mov al, byte [bx]
	call print_hex8_rmode
	mov al, ' '
	call print_char_rmode

	inc bx

	cmp bx, 0x8000
	je .done
	jmp .print_loop
.done:
	mov al, 10
	call print_char_rmode
	mov al, 13
	call print_char_rmode

	panic '[_start] spark not implemented.'

include 'source/print.asm'
include 'source/serial.asm'
include 'source/memtrack.asm'
include 'source/panic.asm'
include 'source/assert.asm'
include 'source/disk/blk_bios.asm'
include 'source/disk/vol.asm'

late_str_finalize
