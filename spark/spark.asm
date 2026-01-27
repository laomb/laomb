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

	unsafe_read_disk 0, 1, 0xd000

	mov cx, 512
	mov si, 0xd000
.mbr_print_loop:
	lodsb
	call print_hex8_16

	mov al, ' '
	call print_char16

	loop .mbr_print_loop

	mov ax, 13
	call print_char16
	mov ax, 10
	call print_char16

	call fat12_init

	mov si, str_boot_init
	call fat12_find_file
	jc .ini_nf

	push ebx

	mov si, str_boot_init
	xor ecx, ecx

	mov di, 0x6000
	mov es, di
	xor di, di

	call fat12_read_file
	jc .ini_nf

	print 10, '      BOOT INIT', 10
	print '--------------------', 10

	xor si, si
	pop ecx

	test cx, cx
	jz .done

	push es
	pop ds
.boot_ini_print_loop:
	lodsb
	call print_char16

	loop .boot_ini_print_loop

	print 10
	jmp .done

.ini_nf:
	jmp $

.done:
	push cs
	pop ds

	jmp $

include 'source16/print.asm'
include 'source16/serial.asm'
include 'source16/arena.asm'
include 'source16/disk.asm'
include 'source16/volume.asm'
include 'source16/fat12.asm'

str_boot_init: db 'BOOT    INI'
loom_83: db 'LOOM    BIN'
