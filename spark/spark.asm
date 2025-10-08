org 0x500
use16

_start:
    mov si, msg
    mov ah, 0xe
.loop:
    lodsb
    int 0x10
    
    cmp byte [si], 0
    je .end
    jmp .loop
.end:
    jmp .end

msg: db 13, 10, 'Booted into SPARK successfully!', 13, 10, 0
