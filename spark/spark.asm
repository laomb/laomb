org 0x500
use16

include 'memory_layout.inc'
include 'print.inc'
include 'assert.inc'
include 'panic.inc'

_start:
	mov ax, stack_segment
	mov ss, ax

	mov sp, 0x4000

	call serial_init

	mov al, 13
	call print_char_rmode
	mov al, 10
	call print_char_rmode

	call mem_init
	print 'Memory subsystem initialized!', 10

	call blk_init
	print 'Block device subsystem initialized!', 10

	call fat12_init
	print 'fat12 subsystem initialized!', 10

	call e820_init
	print 'e820 subsystem initialized!', 10

	mov si, str_boot_ini_name
	call fat12_find_file
	jc .not_found

	mov ecx, ebx
	add ecx, 511
	and ecx, 0xFFFFFE00

	mov ax, cx
	call mem_alloc512
	jc .oom

	push di

	mov si, str_boot_ini_name
	call fat12_read_file
	jc .io_fail

	pop si

	call ini_parser_build
	jc .parse_failed

	mov si, str_spark_section
	mov di, str_boot
	call query_string
	jc .init_tui

	mov si, bx
	mov di, str_laomb
	call memcmp_cx
	jz continue_boot16

	mov di, str_dos
	call memcmp_cx
	jz chainboot_msdos

	mov di, str_msdos
	call memcmp_cx
	jz chainboot_msdos

	mov al, byte [bx]
	cmp al, '?'
	je .init_tui

	print_raw 'Invalid boot = ', !cstr(bx | cx), ' found in BOOT.INI', 10, 'Press any key to enter boot manager.', 10
	call ui_getkey

.init_tui:
	call tui

	panic '[_start] TUI returned unexpectedly.'

.not_found:
	jmp .init_tui

.oom:
	panic '[_start] out of heap for BOOT.INI'

.io_fail:
	panic '[_start] BOOT.INI read failed'

.parse_failed:
	panic '[_start] failed to parse BOOT.INI'

.failed_query:
	panic '[_start] failed to query [spark].boot'

chainboot_msdos:
	call check_msdos_present
    cmp al, 0
	je .msdos_not_present

	mov dl, [bootsector.ebr_drive_number]

	mov si, msdos_83
	mov ecx, 512
	mov di, 0x7c00
	call fat12_read_file

	jmp 0x0000:0x7c00

.msdos_not_present:
	panic '[chainboot_msdos.msdos_not_present] MSDOS.HEX not found!'

include 'source/print.asm'
include 'source/serial.asm'
include 'source/memtrack.asm'
include 'source/panic.asm'
include 'source/assert.asm'
include 'source/disk/blk_bios.asm'
include 'source/disk/vol.asm'
include 'source/disk/fat12.asm'
include 'source/ini_parse.asm'
include 'source/e820.asm'
include 'source/boot_laomb.asm'
include 'source/tui.asm'
include 'source32/print.asm'
include 'source32/panic.asm'
include 'source32/assert.asm'
include 'source32/lbf_bounds.asm'
include 'source32/memtrack.asm'
include 'source32/mem_parse.asm'
include 'source32/loader.asm'

str_boot_ini_name: db 'BOOT    INI'
str_spark_section: db 'spark', 0
str_boot: db 'boot', 0
str_laomb: db 'laomb', 0
str_dos: db 'dos', 0
str_msdos: db 'msdos', 0
