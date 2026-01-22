
macro get_drive_parameters errl
    mov ah, 0x8
    int 0x13
    jc errl
end macro
