org 0x7c00

include 'bios/disk.asm'
include 'bios/unsafe_print.asm'

bytes_per_sector = 512
root_dir_entries_count = 0xe0
root_dir_sectors = (root_dir_entries_count * 32 + bytes_per_sector - 1) / bytes_per_sector

jmp short _start
nop

;
; bdb_oem is mostly unused by DOS/BIOS, for this reason we have 4 free words to use for our purposes.
;
; word(0) - word(2): bootstrap stack for frame standartization.
; byte(6): current_cluster counter for fat12 parsing
;
; word(0): far return IP
; word(1): far return CS
; word(2): initial SP
;

label bdb_oem:8
	dw @f
	dw 0
	dw 0x7c00
	dw 0
label bdb_bytes_per_sector:word
	dw bytes_per_sector
label bdb_sectors_per_cluster:byte
	db 1
label bdb_reserved_sectors:word
	dw 1
label bdb_fat_count:byte
	db 2
label bdb_dir_entries_count:word
	dw root_dir_entries_count
label bdb_total_sectors:word
	dw 2880
label bdb_media_descriptor:byte
	db 0xf0
label bdb_sectors_per_fat:word
	dw 9
label bdb_sectors_per_track:word
	dw 18
label bdb_heads:word
	dw 2
label bdb_hidden_sectors:dword
	dd 0
label bdb_large_sector_count:dword
	dd 0

label ebr_drive_number:byte
	db 0
label ebr_windows_nt_flags:byte
	db 0
label ebr_signature:byte
	db 0x29
label ebr_volume_id:dword
	db 0x12, 0x34, 0x56, 0x78
label ebr_volume_label:11
	db 'LAOMB    OS'
label ebr_system_id:8
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

	unsafe_print "Hello World!", endl, 0 ; TODO remove

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

	xor ah, ah
	int 0x16
	jmp 0x0ffff:0

if defined unsafe_print_lstr__count & (unsafe_print_lstr__count > 0)
	unsafe_print_lstr__base = $
	db unsafe_print_lstr__out
end if

rb 510 - ($ - $$)
dw 0xaa55
