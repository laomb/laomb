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

	call vga$init
	call vga$clear

	lea eax, [str_hello_world]
	call vga$print

	jmp $

segment 'DATA', ST_DATA_RW
data_segment

str_hello_world: db 'Hello World from loom!', 10, 0

loom$flat_segment:
	dw ?

include 'source/dev/vga/textmode.asm'
include 'source/dev/vga/crt.asm'

import 'spark', 'boot$memory_map'
import 'spark', 'boot$flat_segment'
