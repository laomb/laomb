format lbf bin 8192
use32

segment 'TEXT', ST_CODE_RX

entry _start
_start:
	xchg bx, bx

	jmp $

segment 'DATA', ST_DATA_RW
data_segment
