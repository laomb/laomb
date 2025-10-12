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
	call fat12_init

	call blk_print

	mov si, test_txt_83
	call fat12_find_file
	jc .not_found

	push ebx

	mov ax, kernel_bounce_buffer_segment
	mov es, ax
	mov di, kernel_bounce_buffer_offset
	xor ecx, ecx

	mov si, test_txt_83
	call fat12_read_file
	jc .io_fail

	pop ebx

	add ebx, kernel_bounce_buffer_offset
	mov di, kernel_bounce_buffer_offset

	print 10, '--- TEST.TXT ---', 10
.print_char_loop:
	mov al, byte [es:di]
	call print_char_rmode

	inc di
	
	cmp di, bx
	je .out

	jmp .print_char_loop

.io_fail:
	print 'I/O Failure!', 10
	jmp .out

.not_found:
	print 'FILE.TXT Not found!', 10

.out:
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
include 'source/disk/fat12.asm'

late_str_finalize
test_txt_83: db 'TEST    TXT'