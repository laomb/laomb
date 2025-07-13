use32

struc drive_geometry
{
  .cylinders     dw ?
  .heads         db ?
  .sectors       db ?
  .drive_number  db ?
}

drive_info drive_geometry

EMIT_LABEL check_drive_parameters
    pusha
    enter_real_mode

    mov dl, [boot_drive_number]
    mov ah, 0x8
    int 0x13
    jc .error

.error:
    mov esi, msg_failed_to_get_drive_parameters
    call print_str_rm

.exit:
    enter_protected_mode
    popa
    ret

msg_failed_to_get_drive_parameters: db 'Failed to get drive parameters!', 13, 10, 0

