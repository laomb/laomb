
macro get_drive_parameters errl
	mov ah, 0x8
	int 0x13
	jc errl
end macro

macro unsafe_read_disk lba*, count*, buffer*
	match =si, lba
	else
		mov si, lba
	end match

	match =al, count
	else
		mov al, count
	end match

	match =bx, count
	else
		mov bx, buffer
	end match

	call disk_read
end macro
