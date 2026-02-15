format lbf bin 8192
use32

include 'llog.asm'

segment 'TEXT', ST_CODE_XO

; code nullptr guard.
loom$_panic0:
	jmp panic$trigger

entry _start
_start:
	mov ax, rel 'IPT'
	mov es, ax

	; load the loader provided flat segment into a 'DATA' global variable.
	lfs edi, [es:boot$flat_segment]
	mov ax, [fs:edi]
	mov [loom$flat_segment], ax

	; relocate the far pointer from the IPT to DATA for the memory manager.
	mov eax, dword [es:boot$memory_map + FarPointer.offset]
	mov dword [loom$memory_map + FarPointer], eax
	mov ax, word [es:boot$memory_map + FarPointer.selector]
	mov word [loom$memory_map + FarPointer.selector], ax

	call vga$init
	call vga$clear

	; register an early vga text mode sinker.
	lea eax, [vga$print]
	call llog$register_sink

	call mm$pfa_init
	call gdt$init
	call idt$init

	ud2

	jmp $

segment 'DATA', ST_DATA_RW
data_segment

loom$flat_segment:
	dw ?

loom$memory_map:
	dp ?

include 'source/dev/vga/textmode.asm'
include 'source/dev/vga/crt.asm'
include 'source/mm/pfa.asm'
include 'source/cpu/table_descriptor.asm'
include 'source/cpu/gdt.asm'
include 'source/cpu/idt.asm'
include 'source/sys/el.asm'
include 'source/sys/shuttle.asm'
include 'source/sys/llog.asm'
include 'source/sys/panic.asm'

import 'spark', 'boot$memory_map'
import 'spark', 'boot$flat_segment'
