format lbf bin 8192
use32

segment 'TEXT', ST_CODE_RX

entry _start
_start:
	mov ax, rel 'IPT'
	mov es, ax

	lfs edi, [es:boot$test_str]
	mov ax, [fs:edi]
	xchg bx, bx

	jmp $

segment 'DATA', ST_DATA_RW
data_segment

import 'spark', 'boot$test_str'
