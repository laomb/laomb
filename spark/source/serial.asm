
COM1_BASE = 0x3f8

REG_DATA = 0
REG_IER = 1
REG_FCR = 2
REG_LCR = 3
REG_MCR = 4
REG_LSR = 5

LSR_THRE = 0x20



print_serial_rmode:
	push ax
.wait:
	mov dx, COM1_BASE + REG_LSR
	in al, dx

	test al, LSR_THRE
	jz .wait

	mov dx, COM1_BASE + REG_DATA
	pop ax
	out dx, al

	ret
