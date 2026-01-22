org spark_stage1_base

include 'bios/disk.asm'
include 'bios/unsafe_print.asm'
include 'memory_layout.asm'

bytes_per_sector = 512
fat_count = 2
sectors_per_fat = 9
reserved_sectors = 1

root_dir_entries_count = 0xe0
root_dir_sectors = (root_dir_entries_count * 32 + bytes_per_sector - 1) / bytes_per_sector

fat_area_sectors = fat_count * sectors_per_fat
root_directory_start = fat_area_sectors + reserved_sectors
data_area_start = root_directory_start + root_dir_sectors

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
	dw reserved_sectors
; bdb_fat_count
	db fat_count
; bdb_dir_entries_count
	dw root_dir_entries_count
; bdb_total_sectors
	dw 2880
; bdb_media_descriptor
	db 0xf0
; bdb_sectors_per_fat
	dw sectors_per_fat
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

	mov es, ax

	; mask cylinder count, we do not need it for any calculations.
	and cl, 0x3f
	mov byte [bdb_sectors_per_track], cl

	; convert 0-based index of the highest head to # of heads.
	inc dh
	mov byte [bdb_heads], dh

	; load root directory into memory.
	mov si, root_directory_start
	mov al, root_dir_sectors
	mov bx, root_dir_buffer
	call disk_read

	; directory entry iterator.
	xor dx, dx
.iterate_root_directory:
	mov cx, 11
	mov si, target_filename
	mov di, bx

	rep cmpsb
	jz .found_spark

	; move to the next directory entry.
	add bx, 32

	inc dx
	cmp dx, root_dir_entries_count
	jl .iterate_root_directory

	jmp spark_not_found_error

.found_spark:
	unsafe_print "Found SPARK.HEX", endl, 0

	jmp $

; Reads AL sectors into memory from SI at ES:BX
; SI = start lba to read
; AL = # sectors to read
; ES:BX = data out buffer
disk_read:
	pusha

	mov di, 3
.retry:
	call lba_to_chs

	; READ SECTOR(S) INTO MEMORY
	; AL = # of sectors to read
	; CH = 0..7 cylinder number
	; CL = 0..5 sector number 1-63
	; DH = head number
	; DL = drive number
	; ES:BX = data out buffer
	mov ah, 0x2
	mov dl, [ebr_drive_number]
	int 0x13

	jnc .ok

	; on error, reset controller and retry.
	call disk_reset

	dec di
	jnz .retry

	jmp floppy_error

.ok:
	popa
	ret

; Converts LBA in SI to CHS in CL/CH/DH
lba_to_chs:
	push ax
	push dx

	mov ax, si

	; quotient is track, remainder is sector index.
	xor dx, dx
	div word [bdb_sectors_per_track] ; LBA

	; adjust sector index to be 1-based for BIOS.
	inc dx
	mov cx, dx

	; quotient is cylinder, remainder is head.
	xor dx, dx
	div word [bdb_heads] ; track

	; head.
	mov dh, dl
	; cylinder low 8 bits.
	mov ch, al

	; cylinder high bits into CL 6..7.
	shl ah, 6
	or cl, ah

	; only restore the drive number, do not overwrite head number.
	pop ax
	mov dl, al

	pop ax
	ret

disk_reset:
	pusha

	; RESET DISK SYSTEM
	; DL = drive
	xor ah, ah
	int 0x13
	jc floppy_error

	popa
	ret

floppy_error:
	unsafe_print "Floppy disk error", endl, 0
	jmp panic

spark_not_found_error:
	unsafe_print "SPARK.HEX not found", endl, 0
	jmp panic

; Prints a string using TELETYPE OUTPUT
; SI = null-terminated string to print
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

target_filename:
	db 'SPARK   HEX'

rb 510 - ($ - $$)
dw 0xaa55
