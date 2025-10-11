

; In: SI = lba, DX = sector count, ES:BX = buffer
; Out: Side effect = DX sectors loaded from lba SI to ES:BX
volume_read:
	cmp byte [bootsector.ebr_drive_number], 0x80
	jb .floppy_read

	panic '[volume_read] mbr support not implemented.'

.floppy_read:
	jmp disk_read



volume_write:
	panic '[volume_write] volume_write not implemented.'
