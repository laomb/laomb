org 0x0000

_start:
    mov al,'C'
    mov ah,0x0e
    int 13h
    
    jmp $