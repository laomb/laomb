
blk.drive_number: db 0
blk.sectors_per_track: db 0
blk.cylinder_count: dw 0
blk.head_count: db 0

blk.edd.size: dw 0
blk.edd.flags: dw 0
blk.edd.physical_cylinders: dd 0
blk.edd.physical_heads: dd 0
blk.edd.physical_sectors_per_track: dd 0
blk.edd.total_sectors: dq 0
blk.edd.bytes_per_sector: dw 0

blk_init:
	pusha
	push es

	assert "[blk_init] invalid segments!", es eq ds, es eq 0

	mov dl, byte [bootsector.ebr_drive_number]
	xor di, di
	xor ax, ax

	mov ah, 0x8
	int 0x13
	jc .fail

	mov byte [blk.drive_number], bl

	mov al, cl
	and al, 0x3f
	mov byte [blk.sectors_per_track], al

	movzx ax, ch
	movzx bx, cl
	and bx, 0xc0
	shl bx, 2

	or ax, bx
	inc ax
	mov word [blk.cylinder_count], ax

	mov al, dh
	inc al
	mov byte [blk.head_count], al

	mov ah, 0x41
	mov bx, 0x55aa
	mov dl, byte [bootsector.ebr_drive_number]
	int 0x13
	jc .no_edd

	cmp bx, 0xaa55
	jne .no_edd

	mov word [blk.edd.size], 0x1e
	lea si, [blk.edd.size]
	xor ax, ax
	mov ah, 0x48
	mov dl, byte [bootsector.ebr_drive_number]
	int 0x13
	jc .bad_edd

	jmp .done_probe

.bad_edd:
	mov word [blk.edd.size], 0
.no_edd:
.done_probe:
	clc

	pop es
	popa
	ret

.fail:
	print 'Failed to get drive parameters.', 10

	stc

	pop es
	popa
	ret



blk_print:
	print 'Boot Block Device Information', 10

	print 'Sectors per track: 0x', byte [blk.sectors_per_track], 10
	print 'Cylinder count: 0x', word [blk.cylinder_count], 10
	print 'Head count: 0x', byte [blk.head_count], 10

	cmp byte [bootsector.ebr_drive_number], 0x80
	jb .print_floppy_type

	print 'Hard Disk', 10
	jmp .done

.print_floppy_type:
	cmp byte [blk.drive_number], 1
	je .flop360
	cmp byte [blk.drive_number], 2
	je .flop1_2
	cmp byte [blk.drive_number], 3
	je .flop720
	cmp byte [blk.drive_number], 4
	je .flop1_44

	print 'Floppy disk (unknown type)', 10

	jmp .done

.flop360:
	print 'Floppy disk (360K)', 10
	jmp .done

.flop1_2:
	print 'Floppy disk (1.2M)', 10
	jmp .done

.flop720:
	print 'Floppy disk (720K)', 10
	jmp .done

.flop1_44:
	print 'Floppy disk (1.44M)', 10

.done:
	push ax
	
	mov al, 10
	call print_char_rmode
	mov al, 13
	call print_char_rmode
	
	pop ax

	ret


; In: AX = lba
; Out: DH = head number, CX[0:5] = sector number, CX[6:15] = track number
; Clobbers DL
lba_to_chs:
	push ax
	push si

	assert "[lba_to_chs] invalid drive geometry", byte [blk.sectors_per_track] ne 0, byte [blk.head_count] ne 0

	xor dx, dx
	movzx si, byte [blk.sectors_per_track]
	div si

	inc dx
	mov cx, dx

	xor dx, dx
	movzx si, byte [blk.head_count]
	div si

	mov dh, dl
	mov ch, al

	shl ah, 6
	or cl, ah

	pop si
	pop ax
	ret


; In: SI = lba, DX = sector count, ES:BX = buffer
; Out: Side effect = DX sectors loaded from lba SI to ES:BX
disk_read:
	pusha

	assert "[disk_read] bx not sector aligned", bx align 512

	cmp byte [bootsector.ebr_drive_number], 0x80
	jb .floppy_read

	panic '[disk_read] hard drive not implemented.'

.floppy_read:
.read_loop:
	push bx dx
	
	mov ax, si
	call lba_to_chs

	mov ah, 0x2
	mov dl, byte [bootsector.ebr_drive_number]
	mov al, 1
	int 0x13
	jc .error_floppy_read

	pop dx bx

	add bx, 512
	jnz .no_wrap
	
	mov ax, es
	add ax, 0x1000
	mov es, ax
.no_wrap:
	inc si

	dec dx
	test dx, dx
	jnz .read_loop

	jmp .done

.error_floppy_read:
	pop dx bx
	popa
	
	stc
	ret

.done:
	popa
	clc
	ret



disk_write:
	panic '[disk_write] disk_write not implemented.'
