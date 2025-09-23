

; in eax -> lba
;    cx  -> sector count
;    edi -> buffer
partition_read:
    mov dl, [boot_drive_number]
    cmp dl, 0x80
    jnb .disk_read

    call disk_read

.disk_read:
    ; stub
.done:
    ret

; in eax -> lba
;    cx  -> sector count
;    edi -> buffer
partition_write:
    mov dl, [boot_drive_number]
    cmp dl, 0x80
    jnb .disk_write

    call disk_write

.disk_write:
    ; stub
.done:
    ret

