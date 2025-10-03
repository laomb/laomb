use32

COM1_BASE = 0x3F8

REG_DATA = 0
REG_IER = 1
REG_FCR = 2
REG_LCR = 3
REG_MCR = 4
REG_LSR = 5

LCR_DLAB = 0x80
LCR_8N1 = 0x03
FCR_ENABLE_FIFO = 0xC7
MCR_DTR_RTS_OUT2 = 0x0B
LSR_THRE = 0x20

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

use32
serial_puts:
    pushad
    @@:
    mov al, [esi]
    test al, al
    jz @f
    call serial_write_char
    inc esi
    jmp @b
    @@:
    popad
    ret

serial_put_nib:
    cmp al, 9
    jbe .d
    add al, 'A' - 10
    jmp .o
.d:
    add al, '0'
.o:
    call serial_write_char
    ret

serial_put_hex8:
    push eax
    mov ah, al
    shr al, 4
    call serial_put_nib
    mov al, ah
    and al, 0x0F
    call serial_put_nib
    pop eax
    ret

serial_crlf:
    push eax
    mov al, 13
    call serial_write_char
    mov al, 10
    call serial_write_char
    pop eax
    ret
