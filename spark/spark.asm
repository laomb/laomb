org 0x500

include 'bios/disk.asm'
include 'memory_layout.asm'
include 'dbg_print.asm'

_start:
	mov ax, stack_segment

	mov ss, ax
	mov sp, stack_top

	call serial_init
	call disk_init

	print 'Disk initialized!', 10

	unsafe_read_disk 0, 1, 0xd000

	mov cx, 512
	mov si, 0xd000
.loop:
	lodsb
	call print_hex8_16

	mov al, ' '
	call print_char16

	loop .loop

	print 10

	jmp $

include 'source16/print.asm'
include 'source16/serial.asm'
include 'source16/arena.asm'
include 'source16/disk.asm'
include 'source16/volume.asm'
