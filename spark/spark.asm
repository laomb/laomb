org 0x0500
use16

include 'macros.inc'

EMIT_LABEL _start
	mov ax, 0x0
	mov ds, ax
	mov es, ax
	xor ax, ax
	mov ss, ax

	mov dl, byte [0x7C24]
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

	mov     esi, msg_hello
	call    print_str

	mov esi, msg_drive
	call print_str

	mov al, dl
	call print_hex8
	call print_endl

_halt:	hlt
	jmp _halt

msg_hello: db 'Loading Spark...', 13, 10, 0
msg_drive: db 'Booted from drive 0x', 0

boot_drive_number: db 0

include 'source/gdt.asm'
include 'source/a20.asm'
include 'source/print.asm'
include 'source/mem.asm'