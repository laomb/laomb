
volume_read:
	cmp byte [ebr_drive_number], 0x80
	jb .floppy_read

	; TODO MBR hard drive read.
	ret

.floppy_read:
	jmp disk_read
