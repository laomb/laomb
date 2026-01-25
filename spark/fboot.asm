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

fat_area_start = reserved_sectors
fat_second_copy_start = reserved_sectors + sectors_per_fat
fat_area_sectors = fat_count * sectors_per_fat
root_directory_start = fat_area_sectors + reserved_sectors
data_area_start = root_directory_start + root_dir_sectors

; address of the last sector that we can load before overwriting stage 1 code.
sanity_sector =  0x7a00

jmp short _start
nop

;
; bdb_oem, mostly unused by DOS/BIOS, for this reason we have 4 free words to use for our purposes.
;
; word(0) - word(2): bootstrap stack for frame standartization.
; word(3): current_cluster counter for fat12 parsing
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
label current_cluster:word at bdb_oem + 6

_start:
	xor ax, ax
	mov ss, ax

	; ensure we are executing at 0x0:0x7c00 as allegedly, some bioses load CS to 0x7c0 and IP to 0.
	mov sp, zj_bytes
	retf

@@:
	pop sp

	mov ds, ax
	mov [ebr_drive_number], dl

	; GET DRIVE PARAMETERS
	; BL = drive type, should be 04h.
	; CH = 0..7 max cylinder
	; CL = 0..5 max sector, 6..7 max cylinder high
	; DH = max head
	; DL = # of drives
	get_drive_parameters
	jc floppy_error

	xor ax, ax
	mov es, ax

	; mask cylinder count, we do not need it for any calculations.
	and cx, 0x3f
	mov word [bdb_sectors_per_track], cx

	; convert 0-based index of the highest head to # of heads.
	inc dh
	mov byte [bdb_heads], dh

	; load root directory into memory.
	unsafe_read_disk root_directory_start, root_dir_sectors, root_dir_buffer

	; directory entry iterator.
	xor dx, dx
.iterate_root_directory:
	mov cx, 11
	mov si, target_filename
	mov di, bx

	cmp byte [bx], 0
	je spark_not_found_error

	rep cmpsb
	jz .found_spark

	; move to the next directory entry.
	add bx, 32

	inc dx
	cmp dx, root_dir_entries_count
	jl .iterate_root_directory

	jmp spark_not_found_error

.found_spark:
	; save the first cluster of spark.hex.
	mov ax, word [bx + 26]
	mov word [current_cluster], ax

	; load the first copy of the FAT into memory
	unsafe_read_disk fat_area_start, sectors_per_fat, fat_buffer

	mov bx, spark_stage2_base

	; maximum cluster length before we assume the FAT is corrupted.
	push word 2849
	mov bp, sp
.load_spark_loop:
	; convert cluster to lba.
	mov si, word [current_cluster]
	add si, 31

	; did we run out of space?
	cmp bx, sanity_sector
	jae too_large_error

	; read one sector.
	unsafe_read_disk si, 1, bx

	; advance to next sector.
	add bx, bytes_per_sector

	; offset = cluster * 3 / 2
	mov ax, word [current_cluster]

	mov cx, 3
	mul cx

	mov cx, 2
	div cx

	; get the next cluster.
	mov si, fat_buffer
	add si, ax
	mov ax, word [si]

	or dx, dx
	jz .even

	; for odd clusters, use the 12 high bits of the word.
.odd:
	shr ax, 4
	jmp .next_cluster

	; for even clusters, use the 12 low bits of the word.
.even:
	and ax, 0x0fff
.next_cluster:
	cmp ax, 0x0ff7
	je fs_corrupt

	cmp ax, 0x0ff8
	jae .read_finish

	; save the next cluster.
	mov word [current_cluster], ax

	; did we walk the entire cluster chain?
	mov ax, word [bp]
	test ax, ax
	jz fs_corrupt

	dec word [bp]

	jmp .load_spark_loop

.read_finish:
	jmp 0x0:spark_stage2_base

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

	; RESET DISK SYSTEM
	; DL = drive
	floppy_disk_reset
	jc floppy_error

	; try again!
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

floppy_error:
	unsafe_print "Floppy disk error", endl, 0
	jmp panic

spark_not_found_error:
	unsafe_print "SPARK.HEX not found", endl, 0
	jmp panic

too_large_error:
	unsafe_print "SPARK.HEX is too large", endl, 0
	jmp panic

fs_corrupt:
	unsafe_print "FAT corruption", endl, 0

panic:
	unsafe_print "Press any key to reboot", endl, 0

	; GET KEYSTROKE
	xor ah, ah
	int 0x16

	jmp 0x0ffff:0

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

if defined unsafe_print_lstr__count & (unsafe_print_lstr__count > 0)
	unsafe_print_lstr__base = $
	db unsafe_print_lstr__out
end if

target_filename:
	db 'SPARK   HEX'

rb 510 - ($ - $$)
dw 0xaa55
