use32

chainboot_msdos:
    mov al, 1
    call print_set_serial_mirror

    mov esi, [root_dir_ptr]
    mov edi, msdos_hex_83_name

    call fat_find_file
    jc .no_msdos_hex

    mov esi, eax

.read_msdos:
    mov edi, 0x00007C00
    mov ecx, 512
    call fat_read

    cmp eax, 2
    jb .read_fail

    enter_real_mode
.chain_rm:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov dl, [boot_drive_number]

    sti
    jmp 0x0000:0x7C00

use32
.no_msdos_hex:
    mov esi, msg_msdos_hex_not_found
    call print_str
    jmp _halt

.read_fail:
    mov esi, msg_msdos_hex_read_fail
    call print_str
    jmp _halt

msdos_hex_83_name: db 'MSDOS   HEX'
msg_msdos_hex_not_found: db 'MSDOS.HEX not found in root directory.', endl, 0
msg_msdos_hex_read_fail: db 'Failed to read MSDOS.HEX (need 512 bytes).', endl, 0
