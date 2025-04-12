org 0x7c00
bits 16

%macro LABEL 1
%push
%assign __addr__ ($ - $$)
%warning LABEL: %1 @ __addr__
%1:
%pop
%endmacro

%define FAT_BUFFER 0x0500
%define DIR_BUFFER 0x2000

jmp short _entry
nop

LABEL bdb_oem
    db "abcdefgh"
LABEL bdb_bytes_per_sector
    dw 512
LABEL bdb_sectors_per_cluster
    db 1
LABEL bdb_reserved_sectors
    dw 1
LABEL bdb_fat_count
    db 2
LABEL bdb_dir_entries_count
    dw 0E0h
LABEL bdb_total_sectors
    dw 2880
LABEL bdb_media_descriptor_type
    db 0F0h 
LABEL bdb_sectors_per_fat
    dw 9
LABEL bdb_sectors_per_track
    dw 18
LABEL bdb_heads
    dw 2
LABEL bdb_hidden_sectors
    dd 0
LABEL bdb_large_sector_count
    dd 0

LABEL ebr_drive_number
    dw 0
LABEL ebr_signature
    db 29h
LABEL ebr_volume_id
    db 12h, 34h, 56h, 78h
LABEL ebr_volume_label
    db 'LAOMB    OS'
LABEL ebr_system_id
    db 'FAT12   '

LABEL _entry
    xor ax,ax
    mov ds,ax
    mov es,ax
    mov ss,ax

    mov sp,0x7c00

    push es
    push word start
    retf

LABEL start
    mov [ebr_drive_number], dx

    mov cx, [bdb_sectors_per_fat]
    mov si, 0
    mov bx, FAT_BUFFER
.load_fat_loop:
    mov ax, [bdb_reserved_sectors]
    add ax, si 
    push bx
    push ax
    call read_sector
    pop ax
    pop bx
    jc disk_error
    add bx, 512
    inc si
    loop .load_fat_loop

    mov al, [bdb_fat_count]
    mov ah, 0
    mul word [bdb_sectors_per_fat]
    add ax, [bdb_reserved_sectors]
    mov di, ax
    
    mov cx, 14
    mov bx, DIR_BUFFER
.load_root_loop:
    push bx
    push di
    call read_sector
    pop di
    pop bx
    jc disk_error
    add bx, 512
    inc di
    loop .load_root_loop

    mov si, DIR_BUFFER
    mov cx, 224
.search_loop:
    cmp byte [si], 0
    je file_not_found
    cmp byte [si], 0xE5
    je next_entry
    mov al, [si+11]
    test al, 0x10
    jnz next_entry

    push si
    call compare_filename
    pop si
    cmp al, 1
    jne next_entry

    mov ax, [si+26]
    cmp ax, 2
    jb file_not_found
    mov [file_cluster], ax
    mov ax, [si+28]
    cmp ax, 0xFFFF
    ja file_too_big
    mov [file_size], ax
    jmp load_file

LABEL next_entry
    add si, 32
    loop start.search_loop

LABEL file_not_found
    mov si, msg_file_not_found
    call print_string
    jmp wait_and_reset

LABEL file_too_big
    mov si, msg_file_too_big
    call print_string
    jmp wait_and_reset

LABEL load_file
    mov ax, 0x0001
    mov es, ax
    xor di, di

.load_cluster:
    mov ax, [file_cluster]
    sub ax, 2
    add ax, 33               ; Convert to LBA (cluster - 2 + 33)

    mov bx, di
    push bx
    push ax
    call read_sector
    pop ax
    pop bx
    jc disk_error

    mov ax, [file_size]
    cmp ax, 512
    jae load_full_cluster

    add di, ax
    mov word [file_size], 0
    jmp load_done

LABEL load_full_cluster
    add di, 512
    sub ax, 512
    mov [file_size], ax

    mov ax, [file_cluster]
    call get_fat_entry
    cmp ax, 0xFF8
    jae load_done
    cmp ax, 0
    je load_done
    mov [file_cluster], ax
    cmp word [file_size], 0
    jne load_file.load_cluster

LABEL load_done
    jmp 0x0001:0x0000

LABEL read_sector
    push ax
    mov dx, ax
    mov ax, dx
    mov bx, 36
    xor dx, dx
    div bx
    mov ch, al

    mov ax, dx
    mov bx, 18
    xor dx, dx
    div bx
    mov dh, al
    mov al, dl
    inc al
    mov cl, al

    mov ax, [ebr_drive_number]
    mov dl, al
    mov ah, 0x02
    mov al, 1
    int 0x13
    pop ax
    jc read_error
    clc
    ret

LABEL read_error
    stc
    ret

LABEL get_fat_entry
    push bx
    push di
    mov bx, ax
    mov ax, bx
    mov cx, 3
    mul cx
    mov cx, 2
    xor dx, dx
    div cx
    mov di, ax
    add di, FAT_BUFFER
    mov ax, [di]
    test bx, 1
    jnz fat_entry_odd
    and ax, 0x0FFF
    jmp fat_entry_done
fat_entry_odd:
    shr ax, 4
fat_entry_done:
    pop di
    pop bx
    ret

LABEL compare_filename
    push si
    push di
    push cx

    mov cx, 11
    mov di, target_filename
    repe cmpsb
    jne .not_equal
    mov al, 1
    jmp .done
.not_equal:
    mov al, 0
.done:
    pop cx
    pop di
    pop si
    ret

LABEL print_string
    push ax
.print_string_loop:
    lodsb
    cmp al, 0
    je .done_print
    mov ah, 0x0E
    int 0x10
    jmp .print_string_loop
.done_print:
    pop ax
    ret

LABEL wait_key
    mov ah, 0
    int 0x16
    ret

LABEL cold_reset
    int 0x19
    jmp $

LABEL wait_and_reset
    call wait_key
    jmp cold_reset

LABEL disk_error
    mov si, msg_disk_error
    call print_string
    jmp wait_and_reset

LABEL file_cluster
    dw 0
LABEL file_size
    dw 0

LABEL target_filename
    db "SPARK   SYS"

LABEL msg_file_not_found
    db "NF", 0
LABEL msg_file_too_big
    db "BIG", 0
LABEL msg_disk_error
    db "ERR", 0

times 510-($-$$) db 0
dw 0xAA55
