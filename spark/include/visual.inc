define endl 13, 10

macro clsscr_rm
{
    pushad
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    popad
}
