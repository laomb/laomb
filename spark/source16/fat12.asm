
fat12_init:
	pusha

	; calculate byte size of the root directory, each fat12 directory entry is 32 bytes.
	mov ax, word [bdb_dir_entries_count]
	shl ax, 5

	; convert to sector, aligned up (512B chunks) and store into a global variable.
	add ax, 511
	shr ax, 9
	mov word [root_dir_sectors], ax

	; calculate the number of sectors taken up by the FAT(s).
	mov ax, word [bdb_sectors_per_fat]
	xor dx, dx

	movzx bx, byte [bdb_fat_count]
	mul bx

	; first data sector = FAT(s) + reserved sectors (bootsector) + root directory.
	add ax, word [bdb_reserved_sectors]
	add ax, word [root_dir_sectors]
	mov word [first_data_sector], ax

	print '[fat12_init] root directory sectors: 0x', word [root_dir_sectors], 10
	print '[fat12_init] first data sector LBA: 0x', word [first_data_sector], 10

	popa
	ret

; [in] AX = cluster number
; [out] AX = LBA
cluster_to_lba:
	push dx bx

	; clusters are 2-based, convert from index to Nth cluster.
	sub ax, 2

	; calculate sector index in the data section.
	movzx bx, byte [bdb_sectors_per_cluster]
	mul bx

	; convert index to LBA.
	add ax, word [first_data_sector]

	pop bx dx
	ret

; [in] AX = current cluster
; [out] AX = next cluster
; [out] CF=1 if EOF
fat12_next_cluster:
	push bx dx di

	; create copies of the current cluster number.
	mov bx, ax
	mov dx, ax

	; calculate the byte offset N * 1.5 = (N * 3) / 2 
	add bx, bx
	add bx, ax
	shr bx, 1

	mov di, fat_buffer

	; read two bytes, together they form the 12-bit cluster number.
	mov al, byte [di + bx]
	inc bx
	mov ah, byte [di + bx]

	; check if the original cluster number was even or odd.
	test dx, 1
	jz .even
	
	; for odd clusters, next cluster is the high 12 bits of ax
.odd:
	shr ax, 4

	; for even clusters, next cluster is the low 12 bits of ax
.even:
	and ax, 0x0fff

	; bad sector marker in cluster chain means corrupted filesystem.
	cmp ax, 0xff7
	je .corrupted

	; 0xff8-0xfff are valid EOF indicators in fat12.
	cmp ax, 0xff8
	jae .eof

	clc
	pop di dx bx
	ret

.eof:
	stc
	pop di dx bx
	ret

	; report the bad sector to the user.
.corrupted:
	mov si, str_fat12_next_cluster_corrupted_fs
	mov cx, str_fat12_next_cluster_corrupted_fs_end - str_fat12_next_cluster_corrupted_fs
	call print_str16

	jmp corrupted_filesystem

; [in] SI = pointer to 83 name
; [out] AX = first cluster
; [out] EBX = file size
fat12_find_file:
	push cx dx di

	; prepare a pointer to the root directory and a bytes-to-scan counter.
	mov di, root_dir_buffer
	mov cx, word [root_dir_sectors]
	shl cx, 9

.next_entry:
	; less then one directory entry?
	cmp cx, 32
	jb .not_found

	; end of directory?
	mov al, byte [di]
	test al, al
	jz .not_found

	; deleted file?
	cmp al, 0xe5
	je .skip_entry

	; lfn entry?
	mov al, [di + 11]
	cmp al, 0xf
	je .skip_entry

	; volume label entry?
	test al, 0x8
	jnz .skip_entry
	
	; subdirectory?
	test al, 0x10
	jnz .skip_entry

	; save 83 name pointer in case we miss the comparison.
	push si

	; compare up to 11 bytes.
	mov dx, 11

	; copy entry name pointer, first 11 bytes of the entry.
	mov bx, di
.compare_loop:
	mov al, byte [bx]
	cmp al, byte [si]
	jne .cmp_miss

	; move to the next byte.
	inc si
	inc bx
	dec dx
	jnz .compare_loop

	pop si

	; load the first cluster number & filesize.
	mov ax, word [di + 26]
	mov ebx, dword [di + 28]

	clc
	pop di dx cx
	ret

.not_found:
	stc
	pop di dx cx
	ret

.cmp_miss:
	pop si
.skip_entry:
	; move to the next fat12 entry.
	add di, 32
	sub cx, 32

	jmp .next_entry

; [in] SI = pointer to 83 name
; [in] ECX = bytes to read (aligned up to next sector)
; [in] ES:DI = destiation buffer (DI **must** be 512-aligned)
fat12_read_file:
	pusha

	; get the actual size & first cluster.
	call fat12_find_file
	jc .not_found

	; request is 0, use the on-disk information.
	test ecx, ecx
	jz .fix_bytes

	; request is more than there is, use the on-disk information.
	cmp ecx, ebx
	ja .fix_bytes

	; first cluster number is invalid.
	test ax, ax
	jz .done

.align_size:
	; align bytes to read up to the next sector.
	add ecx, 511
	and ecx, -512

.next_cluster:
	; eof cluster marker?
	cmp ax, 0xff8
	jae .done

	; done?
	test ecx, ecx
	jz .done

	; get the cluster's lba.
	push ax
	call cluster_to_lba
	mov si, ax
	pop ax

	; read spc sectors for the cluster.
	movzx bx, byte [bdb_sectors_per_cluster]
.search_loop:
	; no more sectors to read in current cluster?
	test bx, bx
	jz .cluster_done

	; done?
	test ecx, ecx
	jz .done

	push ax bx

	; read one sector at a time.
	mov ax, 1
	mov bx, di

	call volume_read
	jc .io_fail

	; adjust the pointer.
	add di, 512
	jnz .no_wrap

	; wrap segment if overflow.
	mov ax, es
	add ax, 0x1000
	mov es, ax
.no_wrap:
	inc si
	sub ecx, 512

	; next sector in cluster.
	pop bx ax
	dec bx

	jmp .search_loop

.cluster_done:
	call fat12_next_cluster
	jc .done

	jmp .next_cluster

.fix_bytes:
	mov ecx, ebx
	jmp .align_size

.io_fail:
	pop bx ax

	print 'I/O failure reading file at LBA: 0x', si, 10, 0
	stc
	popa
	ret

.not_found:
	print 'File not found!', 10
	stc
	popa
	ret

.done:
	clc
	popa
	ret

	; report filesystem corruption to the user.
corrupted_filesystem:
	mov si, str_corrupted_fs
	mov cx, str_corrupted_fs_end - str_corrupted_fs
	call print_str16

	jmp $

first_data_sector: dw 0
root_dir_sectors: dw 0

str_fat12_next_cluster_corrupted_fs: db '[fat12_next_cluster] BAD sector in cluster chain!', 13, 10
str_fat12_next_cluster_corrupted_fs_end:

str_corrupted_fs: db 'Corrupted filesystem, loading aborted', 13, 10
str_corrupted_fs_end:
