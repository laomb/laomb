use32

    COM1_BASE equ 0x3F8

    REG_DATA equ 0
    REG_IER equ 1
    REG_FCR equ 2
    REG_LCR equ 3
    REG_MCR equ 4
    REG_LSR equ 5

    LCR_DLAB equ 0x80
    LCR_8N1 equ 0x03
    FCR_ENABLE_FIFO equ 0xC7
    MCR_DTR_RTS_OUT2 equ 0x0B
    LSR_THRE equ 0x20

serial_init:
; Disable interrupts
    mov dx, COM1_BASE + REG_IER
    xor al, al
    out dx, al

; Enable DLAB
    mov dx, COM1_BASE + REG_LCR
    mov al, LCR_DLAB
    out dx, al

; Set divisor to 3 (38400 baud)
    mov dx, COM1_BASE + REG_DATA
    mov al, 0x03
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

serial_write_char:
.wait:
    push eax
    mov dx, COM1_BASE + REG_LSR
    in al, dx
    test al, LSR_THRE
    jz .wait
    mov dx, COM1_BASE + REG_DATA
    pop eax
    out dx, al
    ret

use16
serial_write_char_rm:
.wait:
    push ax
    mov dx, COM1_BASE + REG_LSR
    in al, dx
    test al, LSR_THRE
    jz .wait
    mov dx, COM1_BASE + REG_DATA
    pop ax
    out dx, al
    ret
