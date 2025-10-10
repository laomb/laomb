macro panic msg
	local __msglbl

	late_str __msglbl, msg, 0

if x86.mode = 16
	push si
	mov si, __msglbl
	call panic_rmode
else if x86.mode = 32
	push esi
	mov esi, __msglbl
	call panic_pmode
end if
end macro
