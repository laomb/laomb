
chainboot_vbr:
    ; load the chainboot target to 0x0000:0x7c00.
    xor ax, ax
    mov es, ax

    ; save the ebr_drive_number as we need to pass it to the vbr.
    mov dl, [ebr_drive_number]
    push dx

    ; load the vbr file.
    mov di, spark_vbr_base
    lea si, [target_83]
    mov ecx, ebx
    call fat12_read_file
	jc _start.target_read_err

    pop dx
    jmp far 0x0000:spark_vbr_base
