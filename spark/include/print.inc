late_str__count = 0
late_str__total = 0
define late_str__out

macro late_str out_ln?, txt&
	virtual at 0
		db txt
		local __size
		__size = $
	end virtual

	if late_str__count = 0
		redefine late_str__out txt
	else
		define late_str__out late_str__out, txt
	end if

	label out_ln at late_str__base + late_str__total

	late_str__total = late_str__total + __size
	late_str__count = late_str__count + 1
end macro

macro late_str_finalize
	if defined late_str__count & (late_str__count > 0)
		late_str__base = $
		db late_str__out
		purge late_str_finalize
	end if
end macro

macro __print_reg8 r?
	push ax

	mov al, r
if x86.mode = 16
	call print_hex8_rmode
else if x86.mode = 32
	call print_hex8_pmode
end if

	pop ax
end macro

macro __print_reg16 r?
	push ax

	mov ax, r
if x86.mode = 16
	call print_hex16_rmode
else if x86.mode = 32
	call print_hex16_pmode
end if

	pop ax
end macro

macro __print_reg32 r?
	push eax

	mov eax, r
if x86.mode = 16
	call print_hex32_rmode
else if x86.mode = 32
	call print_hex32_pmode
end if

	pop eax
end macro

macro __print_sp
if x86.mode = 16
	push ax

	mov ax, sp
	add ax, 2
	call print_hex16_rmode

	pop ax
else if x86.mode = 32
	push eax

	mov eax, esp
	add eax, 4
	call print_hex32_pmode

	pop eax
end if
end macro

macro __print_ip
if x86.mode = 16
	push ax

	call $+3
	pop ax
	sub ax, 3
	call print_hex16_rmode

	pop ax
else if x86.mode = 32
	push eax

	call $+5
	pop eax
	sub eax, 5
	call print_hex32_pmode

	pop eax
end if
end macro

macro __print_cstr lab?
if x86.mode = 16
	push ax
	push si
	
	mov si, lab
	call print_str_rmode

	pop si
	pop ax
else if x86.mode = 32
	push eax
	push esi

	mov esi, lab
	call print_str_pmode

	pop esi
	pop eax
end if
end macro

macro __print_seg sreg?
	push ax

	mov ax, sreg
if x86.mode = 16
	call print_hex16_rmode
else if x86.mode = 32
	call print_hex16_pmode
end if

	pop ax
end macro

macro __print_flags
local __tmp
if x86.mode = 16
	push ax

	pushf
	pop ax
	call print_flags_rmode

	pop ax
else if x86.mode = 32
	push eax

	pushfd
	pop eax
	call print_flags_pmode

	pop eax
end if
end macro

macro __print_cr r
	push eax

	mov eax, r
if x86.mode = 16
	call print_hex32_rmode
else if x86.mode = 32
	call print_hex32_pmode
end if

	pop eax
end macro

macro __print_mem_sz sz?, mexpr&
if x86.mode = 16
	if sz eq byte
		push ax

		mov al, byte [mexpr]
		call print_hex8_rmode

		pop ax
	else if sz eq word
		push ax

		mov ax, word [mexpr]
		call print_hex16_rmode

		pop ax
	else if sz eq dword
		push eax

		mov eax, dword [mexpr]
		call print_hex32_rmode

		pop eax
	else
		err 'unsupported size in __print_mem_sz (16-bit)'
	end if
else if x86.mode = 32
	if sz eq byte
		push eax

		mov al, byte [mexpr]
		call print_hex8_pmode

		pop eax
	else if sz eq word
		push eax

		mov ax, word [mexpr]
		call print_hex16_pmode

		pop eax
	else if sz eq dword
		push eax

		mov eax, dword [mexpr]
		call print_hex32_pmode

		pop eax
	else
		err 'unsupported size in __print_mem_sz (32-bit)'
	end if
end if
end macro

macro __print_addr mexpr&
if x86.mode = 16
	push ax

	lea ax, [mexpr]
	call print_hex16_rmode

	pop ax
else if x86.mode = 32
	push eax

	lea eax, [mexpr]
	call print_hex32_pmode
	
	pop eax
end if
end macro

macro __print_mem mexpr&
if x86.mode = 16
	__print_mem_sz word, mexpr
else if x86.mode = 32
	__print_mem_sz dword, mexpr
end if
end macro

macro __print_char char
if x86.mode = 16
	push ax

	mov al, char
	call print_char_rmode
	match =10, char
		mov al, 13
		call print_char_rmode
	end match

	pop ax
else if x86.mode = 32
	push eax

	mov al, char
	call print_char_pmode
	match =10, char
		mov al, 13
		call print_char_pmode
	end match

	pop eax
end if
end macro

macro __print_ax_hex
if x86.mode = 16
	call print_hex16_rmode
else if x86.mode = 32
	call print_hex16_pmode
end if
end macro

macro __print_eax_hex
if x86.mode = 16
	call print_hex32_rmode
else if x86.mode = 32
	call print_hex32_pmode
end if
end macro

macro print items&
	if build.mode = build.mode.Debug
		iterate __it, items
			__print_one __it
		end iterate
	end if
end macro

macro __print_one a&
	local __done
	__done = 0

	match =al, a
		__print_reg8 al
		__done = 1
	end match
	match =ah, a
		__print_reg8 ah
		__done = 1
	end match
	match =bl, a
		__print_reg8 bl
		__done = 1
	end match
	match =bh, a
		__print_reg8 bh
		__done = 1
	end match
	match =cl, a
		__print_reg8 cl
		__done = 1
	end match
	match =ch, a
		__print_reg8 ch
		__done = 1
	end match
	match =dl, a
		__print_reg8 dl
		__done = 1
	end match
	match =dh, a
		__print_reg8 dh
		__done = 1
	end match

	if __done = 0
		match =ax, a
			__print_reg16 ax
			__done = 1
		end match
		match =bx, a
			__print_reg16 bx
			__done = 1
		end match
		match =cx, a
			__print_reg16 cx
			__done = 1
		end match
		match =dx, a
			__print_reg16 dx
			__done = 1
		end match
		match =si, a
			__print_reg16 si
			__done = 1
		end match
		match =di, a
			__print_reg16 di
			__done = 1
		end match
		match =bp, a
			__print_reg16 bp
			__done = 1
		end match

		match =cs, a
			__print_seg cs
			__done = 1
		end match
		match =ds, a
			__print_seg ds
			__done = 1
		end match
		match =es, a
			__print_seg es
			__done = 1
		end match
		match =fs, a
			__print_seg fs
			__done = 1
		end match
		match =gs, a
			__print_seg gs
			__done = 1
		end match
		match =ss, a
			__print_seg ss
			__done = 1
		end match

		match =sp, a
			__print_sp
			__done = 1
		end match
	end if

	if __done = 0
		match =eax, a
			__print_reg32 eax
			__done = 1
		end match
		match =ebx, a
			__print_reg32 ebx
			__done = 1
		end match
		match =ecx, a
			__print_reg32 ecx
			__done = 1
		end match
		match =edx, a
			__print_reg32 edx
			__done = 1
		end match
		match =esi, a
			__print_reg32 esi
			__done = 1
		end match
		match =edi, a
			__print_reg32 edi
			__done = 1
		end match
		match =ebp, a
			__print_reg32 ebp
			__done = 1
		end match
	end if

	if __done = 0
		match =ip, a
			__print_ip
			__done = 1
		end match
		match =eip, a
			__print_ip
			__done = 1
		end match
		
		match =cr0, a
			__print_cr cr0
			__done = 1
		end match
		match =cr2, a
			__print_cr cr2
			__done = 1
		end match
		match =cr3, a
			__print_cr cr3
			__done = 1
		end match
		match =cr4, a
			__print_cr cr4
			__done = 1
		end match
	end if

	match =flags, a
		__print_flags
		__done = 1
	end match
	match =eflags, a
		__print_flags
		__done = 1
	end match

	if __done = 0
		match &[m], a
			__print_addr m
			__done = 1
		end match
	end if

	if __done = 0
		match [m], a
			__print_mem m
			__done = 1
		else match byte [m], a
			__print_mem_sz byte, m
			__done = 1
		else match word [m], a
			__print_mem_sz word, m
			__done = 1
		else match dword [m], a
			__print_mem_sz dword, m
			__done = 1
		end match
	end if

	if __done = 0
		match =!mem, a
			local __s_mem,__s_free,__s_blocks,__s_bytes_open,__s_bytes_close,__s_used,__s_total,__s_comma_sp,__s_paren_open,__s_paren_close,__s_eq,__s_sp

			late_str __s_mem, 'mem: ',0
			late_str __s_free, 'free = 0x',0
			late_str __s_used, 'used = 0x',0
			late_str __s_total, 'total = 0x',0
			late_str __s_blocks, ' blocks',0
			late_str __s_bytes_open, ' (0x',0
			late_str __s_bytes_close, ' bytes)',0
			late_str __s_comma_sp, ', ',0

			push ax
			push bx
			push cx
			push dx

			call mem_stats

			mov dx, bx
			add dx, cx

			__print_cstr __s_mem

			__print_cstr __s_free
			__print_reg16 bx

			__print_cstr __s_blocks
			__print_cstr __s_bytes_open
				movzx eax, bx
				shl eax, block_shift
				__print_eax_hex
			__print_cstr __s_bytes_close

			__print_cstr __s_comma_sp

			__print_cstr __s_used
			__print_reg16 cx

			__print_cstr __s_blocks
			__print_cstr __s_bytes_open
				movzx eax, cx
				shl eax, block_shift
				__print_eax_hex
			__print_cstr __s_bytes_close

			__print_cstr __s_comma_sp

			__print_cstr __s_total
			__print_reg16 dx
			__print_cstr __s_blocks
			__print_char 10

			pop dx
			pop cx
			pop bx
			pop ax

			__done = 1
		end match
	end if

	if __done = 0
		if a eqtype 1
			__print_char a
			__done = 1
		end if
	end if

	if __done = 0
		if string? a
			local __s
			late_str __s, a, 0
			__print_cstr __s
		else
			err 'invalid specifier'
		end if
	end if
end macro
