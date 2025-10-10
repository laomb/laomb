org 0x7c00
use16

include 'memory_layout.inc'

define load_seg 0x0000
define endl 13, 10

bytes_per_sector = 512
root_dir_entries_count = 0xe0
root_dir_sectors = (root_dir_entries_count * 32 + bytes_per_sector - 1) / bytes_per_sector

last_sector_before_stage1 = 0x7a00

	jmp short _start
	nop

curr_cluster: ; first word of OEM string is used as cluster number
bdb_oem: times 4 dw 0
bdb_bytes_per_sector: dw bytes_per_sector
bdb_sectors_per_cluster: db 1
bdb_reserved_sectors: dw 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw root_dir_entries_count
bdb_total_sectors: dw 2880
bdb_media_descriptor: db 0xf0
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2
bdb_hidden_sectors: dd 0
bdb_large_sector_count: dd 0

ebr_drive_number: db 0
ebr_windows_nt_flags: db 0
ebr_signature: db 0x29
ebr_volume_id: db 0x12, 0x34, 0x56, 0x78
ebr_volume_label: db 'LAOMB    OS'
ebr_system_id: db 'FAT12   '

_start:
	cld
	xor ax, ax
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov sp, 0x7c00

	push word 0
	push word @f
	retf

@@:
	mov [ebr_drive_number], dl

	push es
	mov ah, 0x8
	int 0x13
	jc floppy_error
	pop es

	call print_progress_dot

	and cl, 0x3f
	xor ch, ch
	mov [bdb_sectors_per_track], cx
	inc dh
	mov byte [bdb_heads], dh

	mov ax, [bdb_sectors_per_fat]
	movzx bx, [bdb_fat_count]
	mul bx
	add ax, [bdb_reserved_sectors]

	mov al, root_dir_sectors
	mov bx, root_dir_buffer
	call disk_read

	call print_progress_dot

	xor bx, bx
	mov di, root_dir_buffer

.search_spark:
	mov si, target_file
	mov cx, 11
	push di
	repe cmpsb
	pop di
	je .found_spark

	add di, 32
	inc bx
	cmp bx, [bdb_dir_entries_count]
	jl .search_spark

	jmp kernel_not_found_error

.found_spark:
	call print_progress_dot

	mov ax, [di + 26]
	mov [curr_cluster], ax
	mov ax, [bdb_reserved_sectors]

	mov bx, fat_buffer
	mov cx, [bdb_sectors_per_fat]
	call disk_read

	push word load_seg
	pop es
	mov bx, stage2_base

	push word 2849
	mov bp, sp
.load_spark_loop:
	mov ax, [curr_cluster]
	add ax, 31

	mov cl, 1

	cmp bx, last_sector_before_stage1
	jae too_large_error

	call disk_read
	call print_progress_dot

	add bx, [bdb_bytes_per_sector]

	mov ax, [curr_cluster]
	
	mov cx, 3
	mul cx
	
	mov cx, 2
	div cx

	mov si, fat_buffer
	add si, ax
	mov ax, [si]

	or dx, dx
	jz .even

.odd:
	shr ax, 4
	jmp .next_cluster

.even:
	and ax, 0x0fff

.next_cluster:
	cmp ax, 0x0ff8
	jae .read_finish

	mov [curr_cluster], ax

	mov ax, word [bp]
	test ax, ax
	jz fs_corrupt

	dec word [bp]

	jmp .load_spark_loop

.read_finish:
	call print_progress_dot
	jmp load_seg:stage2_base

panic:
	mov si, msg_key_to_reboot
	call puts

	mov ah, 0
	int 0x16
	jmp 0x0ffff:0

fs_corrupt:
	mov si, msg_fs_corrupt
	call puts
	jmp panic

floppy_error:
	mov si, msg_disk_error
	call puts
	jmp panic

kernel_not_found_error:
	mov si, msg_not_found
	call puts
	jmp panic

too_large_error:
	mov si, msg_too_large
	call puts
	jmp panic

print_progress_dot:
	pusha
	
	mov al,'.'
	mov ah,0x0E
	xor bx,bx
	int 0x10
	
	popa
	ret

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

lba_to_chs:
	push ax
	push dx

	xor dx, dx
	div word [bdb_sectors_per_track]
	inc dx

	mov cx, dx

	xor dx, dx
	div word [bdb_heads]

	mov dh, dl
	mov ch, al

	shl ah, 6
	or cl, ah
	
	pop ax
	mov dl, al ; only restore low bits of dx

	pop ax
	ret

disk_read:
	pusha
	mov di, 3

.retry:
	call lba_to_chs

	mov ah, 0x2
	mov dl, [ebr_drive_number]
	stc
	int 0x13
	jnc .ok

	call disk_reset

	dec di
	jnz .retry

	jmp floppy_error

.ok:
	popa
	ret

disk_reset:
	pusha

	xor ah, ah
	stc
	int 0x13
	jc floppy_error
	
	popa
	ret

msg_disk_error: db 'Floppy error', endl, 0
msg_not_found: db 'Not found', endl, 0
msg_too_large: db 'Too large', endl, 0
msg_fs_corrupt: db 'Fs corrupt', endl, 0
msg_key_to_reboot: db 'Press any key', endl, 0
target_file: db 'SPARK   HEX'

	rb 510 - ($ - $$)
	dw 0xaa55

