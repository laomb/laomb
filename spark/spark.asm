org 0x0500
use16

include 'macros.inc'

EMIT_LABEL _start
	mov ax, 0x0
	mov ds, ax
	mov es, ax
	xor ax, ax
	mov ss, ax

	mov [boot_drive_number], dl

	mov sp, 0x7C00
	mov bp, sp

	clsscr_rm
	
	cli
	call bootstrap_enable_a20
	call bootstrap_init_gdt

	mov eax, cr0
	or al, 1
	mov cr0, eax

	jmp far GDT_SEL_CODE32:_protected_mode
EMIT_LABEL _protected_mode
	use32

	mov ax, GDT_SEL_DATA32
	mov ds, ax
	mov es, ax
	mov ss, ax

	call serial_init

	mov esi, msg_drive
	call print_str
	mov al, [boot_drive_number]
	call print_hex8
	call print_endl

	call get_e820_map
	
	call print_e820_map

	mov esi, msg_done
	call print_str

_halt:	hlt
	jmp _halt

msg_drive: db 'Booted from drive 0x', 0
msg_done: db 'Loading finalized!', 13, 10, 0

boot_drive_number: db 0

include 'source/gdt.asm'
include 'source/a20.asm'
include 'source/serial.asm'
include 'source/print.asm'
include 'source/bitmap.asm'
include 'source/e820.asm'