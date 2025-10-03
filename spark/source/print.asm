use32

print_serial_mirror_enabled: db 1

print_set_serial_mirror:
    mov [print_serial_mirror_enabled], al
    ret

print_char:
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

    cmp byte [print_serial_mirror_enabled], 0
    je .skip_serial_pm
    call serial_write_char
.skip_serial_pm:

    popad
    ret

print_endl:
    mov al, 0x0d
    call print_char
    mov al, 0x0a
    call print_char
    ret

print_str:
    pushad
.next_char:
    mov al, [esi]
    test al, al
    jz .done_str
    call print_char
    inc esi
    jmp .next_char
.done_str:
    popad
    ret

print_hex8:
    pushad
    mov bl, al
    shr al, 4
    call _print_nibble
    mov al, bl
    and al, 0xF
    call _print_nibble
    popad
    ret

print_hex16:
    pushad
    mov edx, eax
    and edx, 0xFFFF

    mov ecx, edx
    shr ecx, 12
    mov al, cl
    call _print_nibble

    mov ecx, edx
    shr ecx, 8
    and ecx, 0xF
    mov al, cl
    call _print_nibble

    mov ecx, edx
    shr ecx, 4
    and ecx, 0xF
    mov al, cl
    call _print_nibble

    mov al, dl
    and al, 0xF
    call _print_nibble

    popad
    ret

print_hex32:
    pushad
    mov ebx, eax

    mov ecx, ebx
    shr ecx, 28
    mov al, cl
    call _print_nibble

    mov ecx, ebx
    shr ecx, 24
    and ecx, 0xF
    mov al, cl
    call _print_nibble

    mov ecx, ebx
    shr ecx, 20
    and ecx, 0xF
    mov al, cl
    call _print_nibble

    mov ecx, ebx
    shr ecx, 16
    and ecx, 0xF
    mov al, cl
    call _print_nibble

    mov ecx, ebx
    shr ecx, 12
    and ecx, 0xF
    mov al, cl
    call _print_nibble

    mov ecx, ebx
    shr ecx, 8
    and ecx, 0xF
    mov al, cl
    call _print_nibble

    mov ecx, ebx
    shr ecx, 4
    and ecx, 0xF
    mov al, cl
    call _print_nibble

    mov al, bl
    and al, 0xF
    call _print_nibble

    popad
    ret

_print_nibble:
    cmp al, 9
    jg .letter
    add al, '0'
    jmp .have_ascii
.letter:
    add al, 'A'- 10
.have_ascii:
    call print_char
    ret

; in esi -> pointer
;    eax -> size
;    ecx -> granuality (1 = byte, 2 = word, 4 = dword)
print_buffer:
    pushad

    movzx ebx, cl
    xor edx, edx
    mov ecx, ebx
    div ecx
    mov ecx, eax

.print_loop:
    test ecx, ecx
    jz .print_done

    cmp bl, 1
    je .pb_print8
    cmp bl, 2
    je .pb_print16

    mov eax, [esi]
    call print_hex32
    jmp .pb_after

.pb_print16:
    mov ax, [esi]
    call print_hex16
    jmp .pb_after

.pb_print8:
    mov al, [esi]
    call print_hex8

.pb_after:
    mov al, ' '
    call print_char

    add esi, ebx
    dec ecx
    jmp .print_loop

.print_done:
    call print_endl
    popad
    ret


use16
print_char_rm:
    cmp byte [print_serial_mirror_enabled], 0
    je .no_serial_rm
    call serial_write_char_rm
.no_serial_rm:

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

print_endl_rm:
    mov al, 0x0D
    call print_char_rm
    mov al, 0x0A
    call print_char_rm
    ret

print_str_rm:
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

print_hex8_rm:
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

print_hex16_rm:
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

print_hex32_rm:
; dx:ax
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

_print_nibble_rm:
    cmp al, 9
    jg .letter
    add al, '0'
    jmp .print
.letter:
    add al, 'A'- 10
.print:
    call print_char_rm
    ret
