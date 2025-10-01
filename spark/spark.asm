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
    mov eax, 512
    call allocate_memory
    test eax, eax
    jz .mem_alloc_failed
    mov edi, eax

    xor eax, eax
    mov cx, 1
    mov dl, [boot_drive_number]
    call partition_read

    mov esi, edi
    mov eax, 512
    mov ecx, 2
    call print_buffer

    jmp .after_read

.mem_alloc_failed:
    mov esi, msg_mem_alloc_failed
    call print_str
    call print_endl

.after_read:
    call fat12_initialize

    mov esi, [root_dir_ptr]
    mov edi, test_txt_name
    call fat_find_file
    jc .open_fail

    mov esi, eax
    mov ecx, [esi + FILE_SIZE_OFF]
    mov eax, ecx

    inc eax
    call allocate_memory
    test eax, eax
    jz .alloc_fail

    mov edi, eax
    mov ebx, eax

    call fat_read

    mov byte [edi + eax], 0

    mov esi, ebx
    call print_str
    call print_endl
    jmp .done_test

.open_fail:
    mov esi, msg_open_fail
    call print_str
    call print_endl
    jmp .done_test

.alloc_fail:
    mov esi, msg_alloc_fail
    call print_str
    call print_endl

.done_test:
    mov esi, msg_done
    call print_str

_halt: hlt
    jmp _halt

msg_drive: db 'Booted from drive 0x', 0
msg_done: db 'Loading finalized!', 13, 10, 0
msg_mem_alloc_failed: db 'Failed to allocate memory for boot sector', 0

boot_drive_number: db 0

test_txt_name: db 'TEST    TXT', 0
msg_open_fail: db 'Failed to open TEST.TXT', 0
msg_alloc_fail: db 'Failed to allocate buffer for TEST.TXT', 0

include 'source/gdt.asm'
include 'source/a20.asm'
include 'source/serial.asm'
include 'source/print.asm'
include 'source/bitmap.asm'
include 'source/e820.asm'
include 'source/disk.asm'
include 'source/mbr.asm'
include 'source/fat12.asm'
