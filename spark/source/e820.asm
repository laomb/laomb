use32

    E820_MAX_ENTRIES equ 32
    E820_ENTRY_SIZE equ 20

    E820_BASE_LOW equ 0
    E820_BASE_HIGH equ 4
    E820_LENGTH_LOW equ 8
    E820_LENGTH_HIGH equ 12
    E820_TYPE equ 16
    E820_ENTRY_SIZE equ 20

e820_map: rb E820_MAX_ENTRIES * E820_ENTRY_SIZE
e820_entry_count: dd 0

get_e820_map:
    pushad

    enter_real_mode

    mov di, e820_map
    xor ebx, ebx
    mov bp, E820_MAX_ENTRIES

.e820_loop:
    xor ax, ax
    mov es, ax
    mov eax, 0xE820
    mov edx, 0x534D4150
    mov ecx, E820_ENTRY_SIZE

    int 0x15
    jc .done_e820
    cmp eax, 0x534D4150
    jne .done_e820

    mov ax, [e820_entry_count]
    inc ax
    mov [e820_entry_count], ax

    add di, E820_ENTRY_SIZE
    dec bp
    jz .done_e820

    test ebx, ebx
    jnz .e820_loop

.done_e820:
    enter_protected_mode

    popad
    ret

print_e820_map:
    pushad
    xor ecx, ecx
    mov edi, e820_map

    mov esi, msg_count
    call print_str
    mov eax, [e820_entry_count]
    call print_hex32
    call print_endl

.loop:
    mov eax, [e820_entry_count]
    cmp ecx, eax
    jge .done

    mov esi, msg_base
    call print_str
    mov eax, [edi+E820_BASE_HIGH]
    call print_hex32
    mov eax, [edi+E820_BASE_LOW]
    call print_hex32
    call print_endl

    mov esi, msg_size
    call print_str
    mov eax, [edi+E820_LENGTH_HIGH]
    call print_hex32
    mov eax, [edi+E820_LENGTH_LOW]
    call print_hex32
    call print_endl

    mov esi, msg_type
    call print_str
    mov eax, [edi+E820_TYPE]
    call print_hex32
    call print_endl

    add edi, E820_ENTRY_SIZE
    inc ecx
    jmp .loop

.done:
    popad
    ret

msg_base: db 'BASE: 0x', 0
msg_size: db 'SIZE: 0x', 0
msg_type: db 'TYPE: 0x', 0
msg_count: db 'E820 Memory map entries: 0x', 0
