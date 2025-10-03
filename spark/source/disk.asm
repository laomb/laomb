use32

include 'include/disk_structs.inc'

    drive_geometry drive_geometry_t

    edd_packet edd_packet_t

check_disk_parameters:
    pushad
    enter_real_mode

    mov dl, [boot_drive_number]

    xor ax, ax
    mov es, ax
    xor di, di
    mov ah, 0x08
    int 0x13
    jc .err_fail

    mov [drive_geometry.disk_drive_number], bl

    mov al, cl
    and al, 0x3F
    mov [drive_geometry.sectors_per_track], al

    mov ah, cl
    and ah, 0xC0
    shl ah, 2
    mov al, ch
    or ax, ax
    inc ax
    mov [drive_geometry.cylinder_count], ax

    mov al, dh
    inc al
    mov [drive_geometry.head_count], al

    mov word [drive_geometry.edd_size], 0

    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive_number]
    int 0x13
    jc .skip_edd
    cmp bx, 0x0AA55
    jne .skip_edd

    mov word [drive_geometry.edd_size], 0x1E
    lea si, [drive_geometry.edd_size]
    xor ax, ax
    mov ds, ax
    mov ah, 0x48
    mov dl, [boot_drive_number]
    int 0x13
    jc .bad_edd

    jmp .done_probe

.bad_edd:
    mov word [drive_geometry.edd_size], 0

.skip_edd:
.done_probe:
    enter_protected_mode
    popad
    ret

.err_fail:
    mov esi, msg_failed_to_get_drive_parameters
    call print_str_rm

    enter_protected_mode
    popad
    ret

print_disk_parameters:
    pushad

    mov esi, msg_sector_count_print
    call print_str
    mov al, [drive_geometry.sectors_per_track]
    call print_hex8
    call print_endl

    mov esi, msg_cylinder_count_print
    call print_str
    mov ax, [drive_geometry.cylinder_count]
    call print_hex16
    call print_endl

    mov esi, msg_head_count_print
    call print_str
    mov al, [drive_geometry.head_count]
    call print_hex8
    call print_endl

    mov dl, [boot_drive_number]
    cmp dl, 0x80
    jb .print_floppy

    mov esi, msg_hard_disk
    call print_str
    call print_endl

    mov ax, [drive_geometry.edd_size]
    cmp ax, 0
    je .no_edd

    mov esi, msg_total_sectors_print
    call print_str
    mov eax, dword [drive_geometry.edd_total_secs]
    call print_hex32
    mov eax, dword [drive_geometry.edd_total_secs + 4]
    call print_hex32
    call print_endl

    mov esi, msg_bytes_per_sector_print
    call print_str
    mov ax, [drive_geometry.edd_bps]
    call print_hex16
    call print_endl
    jmp .done

.no_edd:
    mov esi, msg_no_edd_support
    call print_str
    call print_endl
    jmp .done

.print_floppy:
    mov al, [drive_geometry.disk_drive_number]
    cmp al, 1 ;   360 K
    je .flop360
    cmp al, 2 ;   1.2 M
    je .flop1_2
    cmp al, 3 ;   720 K
    je .flop720
    cmp al, 4 ;   1.44 M
    je .flop1_44

    mov esi, msg_floppy_disk_unknown
    call print_str
    call print_endl
    jmp .done

.flop360:
    mov esi, msg_size_360k
    call print_str
    call print_endl
    jmp .done

.flop1_2:
    mov esi, msg_size_1_2m
    call print_str
    call print_endl
    jmp .done

.flop720:
    mov esi, msg_size_720k
    call print_str
    call print_endl
    jmp .done

.flop1_44:
    mov esi, msg_size_1_44m
    call print_str
    call print_endl

.done:
    popad
    ret

; in eax -> lba
; out dh -> heads
;	  cx [0:5] -> sector
;     cx [6:15] -> track
lba_to_chs:
    push eax
    push esi

    xor edx, edx
    movzx esi, byte [drive_geometry.sectors_per_track]
    div esi

    inc dx
    mov cx, dx

    xor edx, edx
    movzx esi, byte [drive_geometry.head_count]
    div esi

    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah

    pop esi
    pop eax
    ret


; in eax -> lba
;    cx  -> sector count
;    edi -> buffer
disk_read:
    pushad

    mov dl, [boot_drive_number]
    cmp dl, 0x80
    jb .floppy_read

    mov byte [edd_packet.size], 0x10
    mov byte [edd_packet.reserved], 0
    mov word [edd_packet.sector_count], cx
    mov dword [edd_packet.lba], eax

    mov ebx, edi
    shr ebx, 4
    mov word [edd_packet.buffer_segment], bx

    mov ebx, edi
    and ebx, 0x0F
    mov word [edd_packet.buffer_offset], bx
    lea si, [edd_packet]

    enter_real_mode
    mov ah, 0x42
    int 0x13
    jc .error_hdd
    enter_protected_mode
    jmp .done_ok

.floppy_read:
    mov esi, eax
    mov edx, ecx

.rd_loop:
    push edi
    push edx

    mov eax, esi
    call lba_to_chs

    enter_real_mode
    linear_to_seg_off edi, es, ebx, bx

    mov ah, 0x02
    mov dl, [boot_drive_number]
    mov al, 1
    int 0x13
    jc .error_floppy_read

    enter_protected_mode

    pop edx
    pop edi

    add edi, 512
    inc esi
    dec edx
    test dx, dx
    jnz .rd_loop

    jmp .done_ok

.error_floppy_read:
    enter_protected_mode
    pop edx
    pop edi
    jmp .error_common

.error_hdd:
    enter_protected_mode
    jmp .error_common

.done_ok:
    popad
    clc
    ret

.error_common:
    popad
    stc
    ret

; in eax -> lba
;    cx  -> sector count
;    edi -> buffer
disk_write:
    pushad

    mov dl, [boot_drive_number]
    cmp dl, 0x80
    jb .floppy_write

    mov byte [edd_packet.size], 0x10
    mov byte [edd_packet.reserved], 0
    mov word [edd_packet.sector_count], cx
    mov dword [edd_packet.lba], eax

    mov ebx, edi
    shr ebx, 4
    mov word [edd_packet.buffer_segment], bx

    mov ebx, edi
    and ebx, 0x0F
    mov word [edd_packet.buffer_offset], bx
    lea si, [edd_packet]

    enter_real_mode
    mov ah, 0x43
    int 0x13
    jc .error_hdd
    enter_protected_mode
    jmp .done_ok

.floppy_write:
    mov esi, eax
    mov edx, ecx

.wr_loop:
    push edi
    push edx

    mov eax, esi
    call lba_to_chs

    enter_real_mode
    linear_to_seg_off edi, es, ebx, bx

    mov ah, 0x03
    mov dl, [boot_drive_number]
    mov al, 1
    int 0x13
    jc .error_floppy_write

    enter_protected_mode

    pop edx
    pop edi

    add edi, 512
    inc esi
    dec edx
    test dx, dx
    jnz .wr_loop

    jmp .done_ok

.error_floppy_write:
    enter_protected_mode
    pop edx
    pop edi
    jmp .error_common

.error_hdd:
    enter_protected_mode
    jmp .error_common

.done_ok:
    popad
    clc
    ret

.error_common:
    popad
    stc
    ret

msg_failed_to_get_drive_parameters: db 'Failed to get drive parameters!', endl, 0

msg_sector_count_print: db 'Sectors/track: 0x', 0
msg_cylinder_count_print: db 'Cylinders: 0x', 0
msg_head_count_print: db 'Heads: 0x', 0

msg_hard_disk: db 'Hard disk', 0
msg_total_sectors_print: db 'Total sectors: 0x', 0
msg_bytes_per_sector_print: db 'Bytes/sector: 0x', 0

msg_no_edd_support: db 'EDD not supported', 0

msg_floppy_disk_unknown: db 'Floppy disk (unknown type)', 0
msg_size_360k: db 'Floppy: 360K', 0
msg_size_1_2m: db 'Floppy: 1.2M', 0
msg_size_720k: db 'Floppy: 720K', 0
msg_size_1_44m: db 'Floppy: 1.44M', 0
