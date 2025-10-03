org 0x0500
use16

include 'include/processor_mode_switch.inc'
include 'include/ctype.inc'
include 'include/gdt.inc'
include 'include/visual.inc'

_start:
    mov ax, 0x0
    mov ds, ax
    mov es, ax
    xor ax, ax
    mov ss, ax

    mov [boot_drive_number], dl

    mov sp, 0x7C00
    mov bp, sp

    clsscr_rm

    cli
    call bootstrap_enable_a20
    call bootstrap_init_gdt

    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp far GDT_SEL_CODE32:_protected_mode
use32
_protected_mode:

    mov ax, GDT_SEL_DATA32
    mov ds, ax
    mov es, ax
    mov ss, ax

    call serial_init

    mov esi, msg_drive
    call print_str
    mov al, [boot_drive_number]
    call print_hex8
    call print_endl

    call get_e820_map
    call print_e820_map

    call check_disk_parameters
    call print_disk_parameters

.done_test:
    call tui_enter

_halt: hlt
    jmp _halt

boot_laomb:
    mov al, 1
    call print_set_serial_mirror

    mov esi, msg_boot_laomb
    call serial_puts

    jmp _halt

chainboot_msdos:
    mov al, 1
    call print_set_serial_mirror

    mov esi, msg_chainload_msdos
    call serial_puts

    jmp _halt

msg_drive: db 'Booted from drive 0x', 0
boot_drive_number: db 0

msg_boot_laomb: db 'Booting LAOMB', endl, 0
msg_chainload_msdos: db 'Chainloading MS-DOS', endl, 0

include 'source/gdt.asm'
include 'source/a20.asm'
include 'source/serial.asm'
include 'source/print.asm'
include 'source/bitmap.asm'
include 'source/e820.asm'
include 'source/disk.asm'
include 'source/mbr.asm'
include 'source/fat12.asm'
include 'source/tui.asm'
