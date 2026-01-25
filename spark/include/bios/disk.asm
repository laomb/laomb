
macro get_drive_parameters
	mov ah, 0x8
	int 0x13
end macro

macro edd_installation_check
	mov ah, 0x41
	mov bx, 0x55aa
	mov dl, byte [ebr_drive_number]
	int 0x13
end macro

macro edd_get_drive_parameters
	mov ah, 0x48
	mov dl, byte [ebr_drive_number]
	int 0x13
end macro

macro floppy_disk_reset
	pusha

	xor ah, ah
	int 0x13

	popa
end macro

macro unsafe_read_disk lba*, count*, buffer*
	match =si, lba
	else
		mov si, lba
	end match

	match =ax, count
	else
		mov ax, count
	end match

	match =bx, count
	else
		mov bx, buffer
	end match

	call disk_read
end macro
