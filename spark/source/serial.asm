
COM1_BASE = 0x3f8

REG_DATA = 0
REG_IER = 1
REG_FCR = 2
REG_LCR = 3
REG_MCR = 4
REG_LSR = 5

LCR_DLAB = 0x80
LCR_8N1 = 0x3
FCR_ENABLE_FIFO = 0xc7
MCR_DTR_RTS_OUT2 = 0xb
LSR_THRE = 0x20



serial_init:
	mov dx, COM1_BASE + REG_IER
	xor al, al
	out dx, al

; Enable DLAB
	mov dx, COM1_BASE + REG_LCR
	mov al, LCR_DLAB
	out dx, al

; Set divisor to 3 (38400 baud)
	mov dx, COM1_BASE + REG_DATA
	mov al, 0x3
	out dx, al
	mov dx, COM1_BASE + REG_IER
	xor al, al
	out dx, al

; Set 8N1 format and clear DLAB
	mov dx, COM1_BASE + REG_LCR
	mov al, LCR_8N1
	out dx, al

; Enable FIFO
	mov dx, COM1_BASE + REG_FCR
	mov al, FCR_ENABLE_FIFO
	out dx, al

; Enable DTR, RTS, OUT2
	mov dx, COM1_BASE + REG_MCR
	mov al, MCR_DTR_RTS_OUT2
	out dx, al

	ret



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
