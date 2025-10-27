format lbf exe 1 nx

segment .data, LBF_ST_DATA_RW, 0x10000
section .data, LBF_SK_DATA, 4096

data.from .data

segment .text, LBF_ST_CODE_RX, 0x10000
section .text, LBF_SK_TEXT, 4096

entry _start
_start:
	xor eax, eax
	mov ebx, 0xDEADBEEF

	cli
.halt: hlt
	jmp .halt
