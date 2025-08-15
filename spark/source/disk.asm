use32

    DISK_CYLINDER_COUNT equ 0
    DISK_HEAD_COUNT equ 2
    DISK_SECTORS_PER_TRACK equ 3
    DISK_DRIVE_NUMBER equ 4

    DISK_EDD_SIZE equ 6
    DISK_EDD_FLAGS equ 8
    DISK_EDD_PHY_CYLS equ 10
    DISK_EDD_PHY_HEADS equ 14
    DISK_EDD_PHY_SPT equ 18
    DISK_EDD_TOTAL_SECS equ 22
    DISK_EDD_BPS equ 30

drive_geometry:
    times 4 dq 0

edd_packet:
    db 0x10 ; packet size = 16
    db 0 ; reserved
    dw 0 ; # of sectors to transfer
    dw 0 ; buffer offset (filled by wrapper)
    dw 0 ; buffer segment
    dq 0 ; starting LBA

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

    mov [drive_geometry+DISK_DRIVE_NUMBER], bl

    mov al, cl
    and al, 0x3F
    mov [drive_geometry+DISK_SECTORS_PER_TRACK], al

    mov ah, cl
    and ah, 0xC0
    shl ah, 2
    mov al, ch
    or ax, ax
    inc ax
    mov [drive_geometry+DISK_CYLINDER_COUNT], ax

    mov al, dh
    inc al
    mov [drive_geometry+DISK_HEAD_COUNT], al

    mov word [drive_geometry+DISK_EDD_SIZE], 0

    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive_number]
    int 0x13
    jc .skip_edd
    cmp bx, 0x0AA55
    jne .skip_edd

    mov word [drive_geometry+DISK_EDD_SIZE], 0x1E
    lea si, [drive_geometry+DISK_EDD_SIZE]
    xor ax, ax
    mov ds, ax
    mov ah, 0x48
    mov dl, [boot_drive_number]
    int 0x13
    jc .bad_edd

    jmp .done_probe

.bad_edd:
    mov word [drive_geometry+DISK_EDD_SIZE], 0

.skip_edd:
.done_probe:
    enter_protected_mode
    popa
    ret

.err_fail:
    mov esi, msg_failed_to_get_drive_parameters
    call print_str_rm

    enter_protected_mode
    popa
    ret

print_disk_parameters:
    pushad
    mov edi, drive_geometry

    mov esi, msg_sector_count_print
    call print_str
    mov al, [edi+DISK_SECTORS_PER_TRACK]
    call print_hex8
    call print_endl

    mov esi, msg_cylinder_count_print
    call print_str
    mov ax, [edi+DISK_CYLINDER_COUNT]
    call print_hex16
    call print_endl

    mov esi, msg_head_count_print
    call print_str
    mov al, [edi+DISK_HEAD_COUNT]
    call print_hex8
    call print_endl

    mov dl, [boot_drive_number]
    cmp dl, 0x80
    jb .print_floppy

    mov esi, msg_hard_disk
    call print_str
    call print_endl

    mov ax, [edi+DISK_EDD_SIZE]
    cmp ax, 0
    je .no_edd

    mov esi, msg_total_sectors_print
    call print_str
    mov eax, [edi+DISK_EDD_TOTAL_SECS]
    call print_hex32
    mov eax, [edi+DISK_EDD_TOTAL_SECS+4]
    call print_hex32
    call print_endl

    mov esi, msg_bytes_per_sector_print
    call print_str
    mov ax, [edi+DISK_EDD_BPS]
    call print_hex16
    call print_endl
    jmp .done

.no_edd:
    mov esi, msg_no_edd_support
    call print_str
    call print_endl
    jmp .done

.print_floppy:
    mov al, [edi+DISK_DRIVE_NUMBER]
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
    popa
    ret

; in EAX -> lba
; out dh -> heads
;	  cx [0:5] -> sector
;     cx [6:15] -> track
lba_to_chs:
    push eax

    xor edx, edx
    div byte [drive_geometry+DISK_SECTORS_PER_TRACK]

    inc dx
    mov cx, dx

    xor edx, edx
    div byte [drive_geometry+DISK_HEAD_COUNT]

    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah

    pop eax
    ret


; in dl -> drive#
;	 eax -> lba
;	 cx -> sector count
; 	 edi -> buffer
disk_read:
    pushad

    cmp dl, 0x80
    jb .floppy_read

    lea si, [edd_packet]
    mov byte [si+0], 0x10
    mov byte [si+1], 0
    mov word [si+2], cx
    mov word [si+4], bx
    mov word [si+6], es
    mov dword [si+8], eax
    mov dword [si+12], 0

    enter_real_mode
    mov ah, 0x42
    int 0x13
    jc .error
    enter_protected_mode
    jmp .done

.floppy_read:
    mov esi, eax
    mov edx, ecx

.flop_loop:
    push edi
    mov eax, esi
    call lba_to_chs

    enter_real_mode
    linear_to_seg_off edi, es, ebx, bx

    mov ah, 0x02
    mov dl, [boot_drive_number]
    mov al, 1
    int 0x13
    jc .error

    enter_protected_mode

    pop edi

    add edi, 512
    inc esi
    dec edx
    cmp edx, edx
    jnz .flop_loop

    jmp .done

.error:
    enter_protected_mode

.done:
    popa
    ret

; in dl -> drive#
;	 eax -> lba
;	 cx -> sector count
; 	 ebx -> buffer
disk_write:
    pushad

    linear_to_seg_off ebx, es, ebx, bx

    cmp dl, 0x80
    jb .floppy_write

    lea si, [edd_packet]
    mov byte [si+0], 0x10
    mov byte [si+1], 0
    mov word [si+2], cx
    mov word [si+4], bx
    mov word [si+6], es
    mov dword [si+8], eax
    mov dword [si+12], 0

    enter_real_mode
    mov ah, 0x43
    int 0x13
    jc .werror
    enter_protected_mode
    jmp .wdone

.floppy_write:
    mov esi, eax
    mov edx, ecx

.wr_loop:
    mov eax, esi
    call lba_to_chs
    enter_real_mode
    mov ah, 0x03
    mov al, 1
    int 0x13
    jc .werror
    enter_protected_mode

    add ebx, 512
    inc esi
    dec edx
    jnz .wr_loop
    jmp .wdone

.werror:
    enter_protected_mode

.wdone:
    popa
    ret

msg_failed_to_get_drive_parameters: db 'Failed to get drive parameters!', 13, 10, 0

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
