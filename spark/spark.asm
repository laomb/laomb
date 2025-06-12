org 0x0500
use16

include 'macros.inc'

EMIT_LABEL _start
	cli
	mov ax, 0x0
	mov ds, ax
	mov es, ax
	xor ax, ax
	mov ss, ax

	mov sp, 0xFFFF
    mov bp, sp

	clsscr_rm
	
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

	hlt

include 'source/gdt.asm'
include 'source/a20.asm'