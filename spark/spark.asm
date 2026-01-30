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
	call memmap_init

	mov ax, si
	call print_hex16_16

	print ' memory entries', 10

	unsafe_read_disk 0, 1, 0xd000

	mov cx, 512
	mov si, 0xd000
.mbr_print_loop:
	lodsb
	call print_hex8_16

	mov al, ' '
	call print_char16

	loop .mbr_print_loop

	print_endl

	call fat12_init

	mov si, str_boot_init
	call fat12_find_file
	jc .ini_nf

	push ebx

	mov si, str_boot_init
	xor ecx, ecx

	mov di, 0x6000
	mov es, di
	xor di, di

	call fat12_read_file
	jc .ini_nf

	print 10, '      BOOT INIT', 10
	print '--------------------', 10

	xor si, si
	pop ecx

	test cx, cx
	jz .done

	push es
	pop ds
.boot_ini_print_loop:
	lodsb
	call print_char16

	loop .boot_ini_print_loop

	print 10
	jmp .done

.done:
	push cs
	pop ds

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

	call inip_get_str
	jz .type_mismatch

	mov si, ax
	lea di, [loom_83]
	call fat12_period_to_83

	print_endl

	lea si, [loom_83]
	mov cx, 11
	call print_str16

	print_endl

	lea si, [loom_83]
	call fat12_find_file
	jc .loom_nf

	mov ax, loom_bounce_buffer_segment
	mov es, ax
	mov di, loom_bounce_buffer_offset
	
	lea si, [loom_83]
	xor ecx, ecx
	call fat12_read_file
	jc .loom_read_err

	jmp ur_bootstrap

.ini_nf:
	print 'BOOT.INI not found', 10
	jmp $

.parse_failed:
	print 'INI Parse Error', 10
	jmp $

.spark_nf:
	print 'Category [spark] not found', 10
	jmp $

.boot_nf:
	print 'Key "boot" not found', 10
	jmp $

.type_mismatch:
	print 'Key "boot" is not a string', 10
	jmp $

.loom_nf:
	print 'Error: Loom file not found on disk', 10
	jmp $

.loom_read_err:
	print 'Error: Failed to read loom data', 10
	jmp $

include 'source16/print.asm'
include 'source16/serial.asm'
include 'source16/arena.asm'
include 'source16/disk.asm'
include 'source16/volume.asm'
include 'source16/fat12.asm'
include 'source16/ini_parse.asm'
include 'source16/rand.asm'
include 'source16/memmap.asm'

include 'sourceur/unreal.asm'
include 'sourceur/loader.asm'
include 'sourceur/paslr.asm'

str_boot_init: db 'BOOT    INI'
loom_83: db 'LOOM    BIN'

str_cat_spark: db 'spark', 0
str_key_boot: db 'boot', 0
