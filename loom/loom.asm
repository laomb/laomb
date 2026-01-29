format lbf bin 8192
use32

; tests for format/lbf.asm

segment 'TEXT', ST_CODE_RX, SF_SHAREABLE

entry _start
_start:
	mov ax, rel 'RESRC'
	mov es, ax
	mov al, byte [es:ascii]

	call far [exit_process]

	call func

	ret

segment 'DATA', ST_DATA_RW
data_segment

msg: db "Hello World", 0

segment 'RESRC', ST_DATA_RO

ascii: db "¯\_(ツ)_/¯", 0

segment 'TEXT', ST_CODE_RX

func:
	ret

export 'MainEntry', _start
import 'loom.bin', 'exit_process'
import 'loom.bin', 'open_handle'

import 'gui.dl', 'message_box'
