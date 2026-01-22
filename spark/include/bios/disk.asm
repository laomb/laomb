
macro get_drive_parameters errl
    mov ah, 0x8
    int 0x13
    jc errl
end macro

macro unsafe_read_disk lba*, count*, buffer*
    mov si, lba
	mov al, count
	mov bx, buffer
	call disk_read
end macro
