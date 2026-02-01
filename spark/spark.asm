org 0x500

include 'bios/disk.asm'
include 'memory_layout.asm'
include 'dbg_print.asm'

_start:
	mov ax, stack_segment

	mov ss, ax
	mov sp, stack_top

	call serial_init
	call disk_init
	call gather_entropy
	call fat12_init
	call e820_init

	mov si, str_boot_init
	call fat12_find_file
	jc .ini_nf

	mov si, str_boot_init
	xor ecx, ecx

	; load boot.ini to 0x6000:0x0000 to save precious space in the first 64KiB.
	mov di, 0x6000
	mov es, di
	xor di, di
	call fat12_read_file
	jc .ini_nf

	; snapshop allocations to be able to free the INI database.
	call arena_mark16
	push ax

	; parse BOOT.INI ini.
	xor si, si
	call inip_parse

	test ax, ax
	jz .parse_failed

	; find the `spark` category.
	mov dx, str_cat_spark
	call inip_find_category

	test ax, ax
	jz .spark_nf

	; find the `boot` key under `spark`
	mov dx, str_key_boot
	call inip_find_entry

	test ax, ax
	jz .boot_nf

	; attempt to read the value as a string/identifier.
	call inip_get_str
	jz .type_mismatch

	; convert the parser boot entry into an 83 name.
	mov si, ax
	lea di, [target_83]
	call fat12_period_to_83

	; free the ini database.
	pop ax
	call arena_rewind16

.boot_target:
	; attempt to load resolved target.
	lea si, [target_83]
	call fat12_find_file
	jc .target_nf

	; loom will never be this small, safe for detecting vbr chainboots.
	cmp ebx, 512
	je chainboot_vbr

	; load loom to the bounce buffer for parsing.
	mov ax, supervisor_bounce_buffer_segment
	mov es, ax
	mov di, supervisor_bounce_buffer_offset

	lea si, [target_83]
	mov ecx, ebx
	call fat12_read_file
	jc .target_read_err

	jmp ur_bootstrap

.wk_boot_target:
	; GET KEYSTROKE
	xor ah, ah
	int 0x16

	jmp .boot_target

.ini_nf:
	print 'BOOT.INI not found', 10, 'Press any key to boot LAOMB', 10
	jmp .wk_boot_target

.parse_failed:
	print 'INI parse error', 10, 'Press any key to boot LAOMB', 10
	jmp .wk_boot_target

.spark_nf:
	print 'Category [spark] not found', 10, 'Press any key to boot LAOMB', 10
	jmp .wk_boot_target

.boot_nf:
	print 'Key "boot" not found', 10, 'Press any key to boot LAOMB', 10
	jmp .wk_boot_target

.type_mismatch:
	print 'Key "boot" is not a string', 10, 'Press any key to boot LAOMB', 10
	jmp .wk_boot_target

.target_nf:
	print 'Error: Boot target file "', !cstr( [target_83] | 11 ) ,'" not found on disk', 10
	jmp panic

.target_read_err:
	print 'Error: Failed to read target file data', 10

panic:
	mov si, str_panic
	mov cx, str_panic_end - str_panic
	call print_str16

	; GET KEYSTROKE
	xor ah, ah
	int 0x16

	jmp 0x0ffff:0

include 'source16/print.asm'
include 'source16/serial.asm'
include 'source16/arena.asm'
include 'source16/disk.asm'
include 'source16/volume.asm'
include 'source16/fat12.asm'
include 'source16/ini_parse.asm'
include 'source16/rand.asm'
include 'source16/chainboot.asm'
include 'source16/e820.asm'

include 'sourceur/unreal.asm'
include 'sourceur/loader.asm'
include 'sourceur/paslr.asm'
include 'sourceur/export.asm'

str_boot_init: db 'BOOT    INI'
target_83: db 'LOOM    BIN'

str_cat_spark: db 'spark', 0
str_key_boot: db 'boot', 0

str_panic: db 'Fatal error — Press any key to reboot!', 10
str_panic_end:
