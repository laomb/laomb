
com1_base = 0x3f8

reg_data = 0x0
reg_interrupt_enabled = 0x1
reg_fifo_control = 0x2
reg_line_control = 0x3
reg_modem_control = 0x4
reg_line_status = 0x5

lcr_dlab = 0x80
lcr_8n1 = 0x3
lsr_thre = 0x20

fcr_enable_fifo = 0x7
mcr_dtr_rts = 0x3

serial_init:
	xor al, al

	mov dx, com1_base + reg_interrupt_enabled
	out dx, al

	; assert DLAB to program blaud.
	mov dx, com1_base + reg_line_control
	mov al, lcr_dlab
	out dx, al

	; program DLL to 3 (38400 baud).
	mov dx, com1_base + reg_data
	mov al, 0x3
	out dx, al

	; ensure DLM is 0.
	mov dx, com1_base + reg_interrupt_enabled
	xor al, al
	out dx, al

	; unassert DLAB and program for 8n1.
	mov dx, com1_base + reg_line_control
	mov al, lcr_8n1
	out dx, al

	; assert fifo, flush rx & tx buffers.
	mov dx, com1_base + reg_fifo_control
	mov al, fcr_enable_fifo
	out dx, al

	; assert data terminal ready & request to send.
	mov dx, com1_base + reg_modem_control
	mov al, mcr_dtr_rts
	out dx, al

	ret

serial_putb16:
	push dx ax

.wait_thre_clear:
	mov dx, com1_base + reg_line_status
	in al, dx

	test al, lsr_thre
	jz .wait_thre_clear

	pop ax

	mov dx, com1_base + reg_data
	out dx, al

	pop dx
	ret
