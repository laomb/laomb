org 0x7C00
use16
format binary

define LOAD_SEG  0x0000
define LOAD_OFF  0x0500
define ENDL      13, 10

jmp short _start
nop

bdb_oem                  db 'MSWIN8.8'
bdb_bytes_per_sector     dw 512
bdb_sectors_per_cluster  db 1
bdb_reserved_sectors     dw 1
bdb_fat_count            db 2
bdb_dir_entries_count    dw 0E0h
bdb_total_sectors        dw 2880
bdb_media_descriptor     db 0F0h
bdb_sectors_per_fat      dw 9
bdb_sectors_per_track    dw 18
bdb_heads                dw 2
bdb_hidden_sectors       dd 0
bdb_large_sector_count   dd 0

ebr_drive_number         db 0
                         db 0
ebr_signature            db 29h
ebr_volume_id            db 12h,34h,56h,78h
ebr_volume_label         db 'LAOMB    OS'
ebr_system_id            db 'FAT12   '

_start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    push word 0
    push word main
    retf

main:
    mov [ebr_drive_number], dl
    
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F
    xor ch, ch
    mov [bdb_sectors_per_track], cx
    inc dh
    mov byte [bdb_heads], dh

    mov ax, [bdb_sectors_per_fat]
    movzx bx, [bdb_fat_count]
    mul bx
    add ax, [bdb_reserved_sectors]
    push ax

    mov ax, [bdb_dir_entries_count]
    shl ax, 5
    xor dx, dx
    div word [bdb_bytes_per_sector]
    test dx, dx
    jz .root_dir_ready
    inc ax
.root_dir_ready:
    mov cl, al
    pop ax
    mov dl, [ebr_drive_number]
    mov bx, buffer
    call disk_read

    xor bx, bx
    mov di, buffer

.search_spark:
    mov si, target_file
    mov cx, 11
    push di
    repe cmpsb
    pop di
    je .found_spark

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_spark

    jmp kernel_not_found_error

.found_spark:
    mov ax, [di+26]
    mov [curr_cluster], ax
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cx, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    mov bx, LOAD_SEG
    mov es, bx
    mov bx, LOAD_OFF

.load_spark_loop:
    mov ax, [curr_cluster]
    add ax, 31
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    mov ax, [curr_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx

    mov si, buffer
    add si, ax
    mov ax, [ds:si]

    or dx, dx
    jz .even
.odd:
    shr ax, 4
    jmp .next_cluster
.even:
    and ax, 0x0FFF
.next_cluster:
    cmp ax, 0x0FF8
    jae .read_finish
    mov [curr_cluster], ax
    jmp .load_spark_loop

.read_finish:
    mov dl, [ebr_drive_number]

    mov ax, LOAD_SEG
    mov ds, ax
    mov es, ax

    jmp LOAD_SEG:LOAD_OFF

    cli
    hlt

floppy_error:
    mov si, msg_disk_error
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov si, msg_key_to_reboot
    call puts

    mov ah, 0
    int 16h
    jmp 0FFFFh:0

.halt:
    cli
    hlt

puts:
    push si
    push ax
    push bx
.put_loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .put_loop
.done:
    pop bx
    pop ax
    pop si
    ret

lba_to_chs:
    push ax
    push dx
    xor dx, dx
    div word [bdb_sectors_per_track]
    inc dx
    mov cx, dx
    xor dx, dx
    div word [bdb_heads]
    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah
    pop ax
    mov dl, al
    pop ax
    ret

disk_read:
    pusha
    push cx
    call lba_to_chs
    pop ax
    mov ah, 02h
    mov di, 3
.retry:
    pusha
    stc
    int 13h
    jnc .read_ok
    popa
    call disk_reset
    dec di
    test di, di
    jnz .retry
    jmp floppy_error
.read_ok:
    popa
    popa
    ret

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_disk_error: db 'Floppy disk error!', ENDL, 0
msg_not_found:  db 'SPARK.HEX not found!', ENDL, 0
msg_key_to_reboot: db 'Press any key to reboot.', ENDL, 0
target_file:    db 'SPARK   HEX'
curr_cluster:   dw 0

rb 510 - ($ - $$)
dw 0xAA55

buffer:
