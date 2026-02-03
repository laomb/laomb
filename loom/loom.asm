format lbf bin 8192
use32

segment 'TEXT', ST_CODE_RX

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

	call mm$init

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

import 'spark', 'boot$memory_map'
import 'spark', 'boot$flat_segment'
