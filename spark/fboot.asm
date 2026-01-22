org spark_stage1_base

include 'bios/disk.asm'
include 'bios/unsafe_print.asm'
include 'memory_layout.asm'

bytes_per_sector = 512
root_dir_entries_count = 0xe0
root_dir_sectors = (root_dir_entries_count * 32 + bytes_per_sector - 1) / bytes_per_sector

jmp short _start
nop

;
; bdb_oem, mostly unused by DOS/BIOS, for this reason we have 4 free words to use for our purposes.
;
; word(0) - word(2): bootstrap stack for frame standartization.
; byte(6): current_cluster counter for fat12 parsing
;
; word(0): far return IP
; word(1): far return CS
; word(2): initial SP
;
	dw @f
	dw 0
	dw spark_stage1_base
	dw 0
; bdb_bytes_per_sector
	dw bytes_per_sector
; bdb_sectors_per_cluster
	db 1
; bdb_reserved_sectors
	dw 1
; bdb_fat_count
	db 2
; bdb_dir_entries_count
	dw root_dir_entries_count
; bdb_total_sectors
	dw 2880
; bdb_media_descriptor
	db 0xf0
; bdb_sectors_per_fat
	dw 9
; bdb_sectors_per_track
	dw 18
; bdb_heads
	dw 2
; bdb_hidden_sectors
	dd 0
; bdb_large_sector_count
	dd 0

; ebr_drive_number
	db 0
; ebr_windows_nt_flags
	db 0
; ebr_signature
	db 0x29
; ebr_volume_id
	db 0x12, 0x34, 0x56, 0x78
; ebr_volume_label
	db 'LAOMB    OS'
; ebr_system_id
	db 'FAT12   '

label zj_bytes:word at bdb_oem
label current_cluster:byte at bdb_oem + 6

_start:
	; clear IF so a conveniently placed SP and interrupt won't corrupt our code.
	cli
	xor ax, ax
	mov ss, ax

	; ensure we are executing at 0x0:0x7c00 as allegedly, some bioses load CS to 0x7c0 and IP to 0.
	mov sp, zj_bytes
	retf

@@:
	pop sp
	sti

	mov ds, ax
	mov [ebr_drive_number], dl

	; GET DRIVE PARAMETERS
	; BL = drive type, should be 04h.
	; CH = 0..7 max cylinder
	; CL = 0..5 max sector, 6..7 max cylinder high
	; DH = max head
	; DL = # of drives
	get_drive_parameters floppy_error

	jmp $

floppy_error:
	unsafe_print "Floppy disk error", endl, 0
	jmp panic

puts:
	lodsb
	test al, al
	jz .done

	mov ah, 0xe
	xor bh, bh
	int 0x10

	jmp puts

.done:
	ret

panic:
	unsafe_print "Press any key to reboot", endl, 0

	; GET KEYSTROKE
	xor ah, ah
	int 0x16

	jmp 0x0ffff:0

if defined unsafe_print_lstr__count & (unsafe_print_lstr__count > 0)
	unsafe_print_lstr__base = $
	db unsafe_print_lstr__out
end if

rb 510 - ($ - $$)
dw 0xaa55
