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

	call tui

	panic '[_start] TUI returned unexpectedly.'

continue_boot:
	panic '[continue_boot] continue_boot is unimplemented.'

chainboot_msdos:
	mov dl, [bootsector.ebr_drive_number]

	mov si, msdos_83
	mov ecx, 512
	mov di, 0x7c00
	call fat12_read_file

	jmp 0x0000:0x7c00

include 'source/print.asm'
include 'source/serial.asm'
include 'source/memtrack.asm'
include 'source/panic.asm'
include 'source/assert.asm'
include 'source/disk/blk_bios.asm'
include 'source/disk/vol.asm'
include 'source/disk/fat12.asm'

include 'source/tui.asm'

late_str_finalize
