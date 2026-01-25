
disk_init:
	pusha

	mov dl, byte [ebr_drive_number]

	xor di, di
	xor ax, ax

	push es

	; GET DRIVE PARAMETERS
	; BL = drive type, should be 04h.
	; CH = 0..7 max cylinder
	; CL = 0..5 max sector, 6..7 max cylinder high
	; DH = max head
	; DL = # of drives
	get_drive_parameters
	jc .drive_parameter_fail

	pop es

	; mask cylinder count, we do not need it for any calculations.
	and cx, 0x3f
	mov word [bdb_sectors_per_track], cx

	; convert 0-based index of the highest head to # of heads.
	inc dh
	mov byte [bdb_heads], dh

.edd_check:
	; Extensions - INSTALLATION CHECK
	; BX = 0xaa55
	; AH = major version of extensions
	; 	   0x1  = 1.x
	;	   0x20 = 2.0 / EDD-1.0
	;	   0x21 = 2.1 / EDD-1.1
	;	   0x30 = EDD-3.0
	; CX = API subset support bitmap
	;	   bit 0 = extended disk access functions support
	;	   bit 1 = removable drive controller functions support
	;	   bit 2 = enhanced disk drive (EDD) functions support
	edd_installation_check
	jc .no_edd

	cmp bx, 0xaa55
	jne .no_edd

	; store the subset bitmap so read/write can query bit 0.
	mov word [edd_subset_bitmap], cx

	bt cx, 2
	jnc .no_edd

	lea si, [edd]
	xor ax, ax

	; Extensions - GET DRIVE PARAMETERS
	; DL = drive
	; DS:SI = buffer for drive parameters (modified inplace)
	edd_get_drive_parameters
	jc .no_edd

	jmp .done

.no_edd:
	; edd not available.
	mov word [edd_size], 0
.done:
	popa
	ret

.drive_parameter_fail:
	pop es

	; attempt edd, otherwise rely on BPB.
	jmp .edd_check

; [in] SI = LBA
; [out] CL/CH/DH = CHS
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

; [in] SI = LBA
; [in] AX = sector count
; [in] ES:BX = buffer
disk_read:
	pusha

	cmp byte [ebr_drive_number], 0x80
	jb .floppy_read

	; TODO edd hard drive read.
	popa
	ret

.floppy_read:
	; set up frame for 4 retries per sector.
	sub sp, 1
	mov bp, sp
	mov byte [bp], 3

	; read sectors into memory, one by one handling segment wrap.
.floppy_loop:
	push ax bx
	call lba_to_chs

	; new sector, new 4 attempts.
	mov byte [bp], 3

.retry_read:
	; READ SECTOR(S) INTO MEMORY
	; AL = # of sectors to read
	; CH = 0..7 cylinder number
	; CL = 0..5 sector number 1-63
	; DH = head number
	; DL = drive number
	; ES:BX = data out buffer
	mov ah, 0x2
	mov al, 0x1
	mov dl, [ebr_drive_number]
	int 0x13
	jc .error_floppy_read

	pop bx ax

	; move pointer to the next sector.
	add bx, 512
	jnz .no_wrap

	; bx == 0, move es to the next 64KiB chunk.
	mov bx, es
	add bx, 0x1000
	mov es, bx
	xor bx, bx
.no_wrap:
	inc si

	dec ax
	jnz .floppy_loop

	; pop frame for retires.
	add sp, 1

	; done.
	clc
	popa
	ret

.error_floppy_read:
	; did we run out of attempts?
	cmp byte [bp], 0
	jz .fail

	; RESET DISK SYSTEM
	; DL = drive
	floppy_disk_reset
	jc .fail

	dec byte [bp]

	; try again!
	jmp .retry_read

.fail:
	pop bx ax

	; pop frame for retires.
	add sp, 1

	stc
	popa
	ret

edd_subset_bitmap: dw 0

edd:
edd_size: dw 0x1e
edd_flags: dw 0
edd_physical_cylinders: dd 0
edd_physical_heads: dd 0
edd_physical_spt: dd 0
edd_total_sectors: dq 0
edd_bytes_per_sector: dw 0
