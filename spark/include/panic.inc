macro panic msg
	local __msglbl

if build.mode = build.mode.Debug
	late_str __msglbl, msg, 0
end if

if x86.mode = 16
if build.mode = build.mode.Debug
	push si
	mov si, __msglbl
end if
	call panic_rmode
else if x86.mode = 32
if build.mode = build.mode.Debug
	push esi
	mov esi, __msglbl
end if
	call panic_pmode
end if
end macro
