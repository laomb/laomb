use32

EMIT_LABEL print_char
    pushad

    push eax

    sub esp, 2
    mov [esp], ax

    enter_real_mode

    pop ax
    mov bh, 0x00
    mov bl, 0x07
    mov ah, 0x0E
    int 0x10

    enter_protected_mode
    pop eax

    call serial_write_char

    popad
    ret

EMIT_LABEL print_endl
    mov al, 0x0d
    call print_char
    mov al, 0x0a
    call print_char
    ret

EMIT_LABEL print_str
    pushad
.next_char:
    mov     al, [esi]
    test    al, al
    jz      .done_str
    call    print_char
    inc     esi
    jmp     .next_char
.done_str:
    popad
    ret

EMIT_LABEL print_hex8
    pushad
    mov     bl, al
    shr     al, 4
    call    _print_nibble
    mov     al, bl
    and     al, 0xF
    call    _print_nibble
    popad
    ret

EMIT_LABEL print_hex16
    pushad
    mov     edx, eax
    and     edx, 0xFFFF

    mov     ecx, edx
    shr     ecx, 12
    mov     al, cl
    call    _print_nibble

    mov     ecx, edx
    shr     ecx,  8
    and     ecx, 0xF
    mov     al, cl
    call    _print_nibble

    mov     ecx, edx
    shr     ecx,  4
    and     ecx, 0xF
    mov     al, cl
    call    _print_nibble

    mov     al, dl
    and     al, 0xF
    call    _print_nibble

    popad
    ret

EMIT_LABEL print_hex32
    pushad
    mov     ebx, eax
    
    mov     ecx, ebx
    shr     ecx, 28
    mov     al, cl
    call    _print_nibble

    mov     ecx, ebx
    shr     ecx, 24
    and     ecx, 0xF
    mov     al, cl
    call    _print_nibble

    mov     ecx, ebx
    shr     ecx, 20
    and     ecx, 0xF
    mov     al, cl
    call    _print_nibble

    mov     ecx, ebx
    shr     ecx, 16
    and     ecx, 0xF
    mov     al, cl
    call    _print_nibble

    mov     ecx, ebx
    shr     ecx, 12
    and     ecx, 0xF
    mov     al, cl
    call    _print_nibble

    mov     ecx, ebx
    shr     ecx,  8
    and     ecx, 0xF
    mov     al, cl
    call    _print_nibble

    mov     ecx, ebx
    shr     ecx,  4
    and     ecx, 0xF
    mov     al, cl
    call    _print_nibble

    mov     al, bl
    and     al, 0xF
    call    _print_nibble

    popad
    ret

EMIT_LABEL _print_nibble
    cmp     al, 9
    jg      .letter
    add     al, '0'
    jmp     .have_ascii
.letter:
    add     al, 'A' - 10
.have_ascii:
    call    print_char
    ret

use16
EMIT_LABEL print_char_rm
    call serial_write_char_rm

    push ax
    push bx
    push dx

    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10

    pop dx
    pop bx
    pop ax
    ret

EMIT_LABEL print_endl_rm
    mov al, 0x0D
    call print_char_rm
    mov al, 0x0A
    call print_char_rm
    ret

EMIT_LABEL print_str_rm
    push ax
.next:
    lodsb
    test al, al
    jz .done
    call print_char_rm
    jmp .next
.done:
    pop ax
    ret

EMIT_LABEL print_hex8_rm
    push ax
    push bx

    mov bl, al
    shr al, 4
    call _print_nibble_rm

    mov al, bl
    and al, 0x0F
    call _print_nibble_rm

    pop bx
    pop ax
    ret

EMIT_LABEL print_hex16_rm
    push ax
    push cx

    mov cx, ax
    mov al, ch
    shr al, 4
    call _print_nibble_rm

    mov al, ch
    and al, 0x0F
    call _print_nibble_rm

    mov al, cl
    shr al, 4
    call _print_nibble_rm

    mov al, cl
    and al, 0x0F
    call _print_nibble_rm

    pop cx
    pop ax
    ret

EMIT_LABEL print_hex32_rm
    ; DX:AX
    push ax
    push dx
    push cx

    mov cx, dx
    mov al, ch
    shr al, 4
    call _print_nibble_rm

    mov al, ch
    and al, 0x0F
    call _print_nibble_rm

    mov al, cl
    shr al, 4
    call _print_nibble_rm

    mov al, cl
    and al, 0x0F
    call _print_nibble_rm

    mov cx, ax
    mov al, ch
    shr al, 4
    call _print_nibble_rm

    mov al, ch
    and al, 0x0F
    call _print_nibble_rm

    mov al, cl
    shr al, 4
    call _print_nibble_rm

    mov al, cl
    and al, 0x0F
    call _print_nibble_rm

    pop cx
    pop dx
    pop ax
    ret

EMIT_LABEL _print_nibble_rm
    cmp al, 9
    jg .letter
    add al, '0'
    jmp .print
.letter:
    add al, 'A' - 10
.print:
    call print_char_rm
    ret
