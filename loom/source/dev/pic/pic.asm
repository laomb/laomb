
PIC_MASTER_CMD = 0x20
PIC_MASTER_DATA = 0x21
PIC_SLAVE_CMD = 0xa0
PIC_SLAVE_DATA = 0xa1

PIC_ICW1_INIT = 0x10
PIC_ICW1_ICW4 = 0x1
PIC_ICW4_8086 = 0x1

PIC_OCW3_READ_IRR = 0xa
PIC_OCW3_READ_ISR = 0xb

PIC_EOI = 0x20

PIC_MASTER_OFFSET = 32
PIC_SLAVE_OFFSET = 40

segment 'TEXT', ST_CODE_XO

; procedure pic$init();
pic$init:
	; ICW1: begin initialization sequence on both PICs.
	mov al, PIC_ICW1_INIT or PIC_ICW1_ICW4
	out PIC_MASTER_CMD, al
	call pic$_io_wait
	out PIC_SLAVE_CMD, al
	call pic$_io_wait

	; ICW2: set vector offsets.
	mov al, PIC_MASTER_OFFSET
	out PIC_MASTER_DATA, al
	call pic$_io_wait
	mov al, PIC_SLAVE_OFFSET
	out PIC_SLAVE_DATA, al
	call pic$_io_wait

	; ICW3: tell master about slave on IRQ2, tell slave its cascade identity.
	mov al, 0x4
	out PIC_MASTER_DATA, al
	call pic$_io_wait
	mov al, 0x2
	out PIC_SLAVE_DATA, al
	call pic$_io_wait

	; ICW4: 8086 mode.
	mov al, PIC_ICW4_8086
	out PIC_MASTER_DATA, al
	call pic$_io_wait
	out PIC_SLAVE_DATA, al
	call pic$_io_wait

	; mask all lines.
	mov al, 0xff
	out PIC_MASTER_DATA, al
	call pic$_io_wait
	mov al, 0xff
	out PIC_SLAVE_DATA, al

	ret

; procedure pic$mask(irq: Byte);
pic$mask:
	movzx ecx, al

	cmp cl, 8
	jae .slave

	; set irq bit on master pic.
	mov dx, PIC_MASTER_DATA
	in al, dx
	bts eax, ecx
	out dx, al

	ret

.slave:
	; set irq bit on slave pic.
	sub cl, 8
	mov dx, PIC_SLAVE_DATA
	in al, dx
	bts eax, ecx
	out dx, al

	ret

; procedure pic$unmask(irq: Byte);
pic$unmask:
	movzx ecx, al

	cmp cl, 8
	jae .slave

	; clear irq bit on master pic.
	mov dx, PIC_MASTER_DATA
	in al, dx
	btr eax, ecx
	out dx, al

	ret

.slave:
	; clear irq bit on sllave pic.
	sub cl, 8
	mov dx, PIC_SLAVE_DATA
	in al, dx
	btr eax, ecx
	out dx, al

	; ensure the cascade line is unmasked on master.
	mov dx, PIC_MASTER_DATA
	in al, dx
	btr eax, 2
	out dx, al

	ret

; procedure pic$send_eoi(irq: Byte);
pic$send_eoi:
	cmp al, 8
	jb .master_only

	mov al, PIC_EOI
	out PIC_SLAVE_CMD, al

	; cascade irq eoi.
.master_only:
	mov al, PIC_EOI
	out PIC_MASTER_CMD, al

	ret

; function pic$get_isr(): Word;
pic$get_isr:
	mov al, PIC_OCW3_READ_ISR
	out PIC_MASTER_CMD, al
	out PIC_SLAVE_CMD, al

	in al, PIC_SLAVE_CMD
	shl eax, 8
	in al, PIC_MASTER_CMD

	ret

; function pic$get_irr(): Word;
pic$get_irr:
	mov al, PIC_OCW3_READ_IRR
	out PIC_MASTER_CMD, al
	out PIC_SLAVE_CMD, al

	in al, PIC_SLAVE_CMD
	shl eax, 8
	in al, PIC_MASTER_CMD

	ret

; function pic$_io_wait(return_value: Cardinal): Cardinal;
pic$_io_wait:
	push eax

	; write to POST port for a delay.
	mov al, 0
	out 0x80, al

	pop eax
	ret
