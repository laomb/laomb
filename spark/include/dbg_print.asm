late_str__count = 0
late_str__total = 0
define late_str__out

macro late_str out_ln*, out_sz*, txt&
	virtual at 0 
		db txt
		out_sz = $
	end virtual

	if late_str__count = 0
		redefine late_str__out txt
	else
		define late_str__out late_str__out, txt
	end if

	label out_ln at late_str__base + late_str__total

	late_str__total = late_str__total + out_sz
	late_str__count = late_str__count + 1
end macro

postpone
	if late_str__count > 0
		late_str__base = $
		db late_str__out
	end if
end postpone

macro __print_char char*
	push ax

	match =10, char
		mov al, 13
		call print_char16
	end match

	mov al, char
	call print_char16

	pop ax
end macro

macro __print_reg8 r*
	match =al, r
		call print_hex8_16
	else
		push ax

		mov al, r
		call print_hex8_16

		pop ax
	end match
end macro

macro __print_reg16 r*
	match =ax, r
		call print_hex16_16
	else
		push ax

		mov ax, r
		call print_hex16_16

		pop ax
	end match
end macro

macro __print_reg32 r*
	match =eax, r
		call print_hex32_16
	else
		push eax

		mov eax, r
		call print_hex32_16

		pop eax
	end match
end macro

macro __print_mem_char mexpr&
	push ax

	mov al, byte [mexpr]
	call print_char_rmode

	pop ax
end macro

macro __print_mem_sz sz*, mexpr&
	if sz eq byte
		push ax

		mov al, byte [mexpr]
		call print_hex8_16

		pop ax
	else if sz eq word
		push ax

		mov ax, word [mexpr]
		call print_hex16_16

		pop ax
	else if sz eq dword
		push eax

		mov eax, dword [mexpr]
		call print_hex32_16

		pop eax
	else
		err 'unsupported size in __print_mem_sz'
	end if
end macro

macro __print_cstr lb*, sz*
	push ax cx si

	mov cx, sz
	mov si, lb
	call print_str16

	pop si cx ax
end macro

macro __print_one a&
	local __done
	__done = 0

	match =al, a
		__print_reg8 al
		__done = 1
	else match =ah, a
		__print_reg8 ah
		__done = 1
	else match =bl, a
		__print_reg8 bl
		__done = 1
	else match =bh, a
		__print_reg8 bh
		__done = 1
	else match =cl, a
		__print_reg8 cl
		__done = 1
	else match =ch, a
		__print_reg8 ch
		__done = 1
	else match =dl, a
		__print_reg8 dl
		__done = 1
	else match =dh, a
		__print_reg8 dh
		__done = 1
	end match

	if __done = 0
		match =ax, a
			__print_reg16 ax
			__done = 1
		else match =bx, a
			__print_reg16 bx
			__done = 1
		else match =cx, a
			__print_reg16 cx
			__done = 1
		else match =dx, a
			__print_reg16 dx
			__done = 1
		else match =si, a
			__print_reg16 si
			__done = 1
		else match =di, a
			__print_reg16 di
			__done = 1
		else match =bp, a
			__print_reg16 bp
			__done = 1
		else match =cs, a
			__print_reg16 cs
			__done = 1
		else match =ds, a
			__print_reg16 ds
			__done = 1
		else match =es, a
			__print_reg16 es
			__done = 1
		else match =fs, a
			__print_reg16 fs
			__done = 1
		else match =gs, a
			__print_reg16 gs
			__done = 1
		else match =ss, a
			__print_reg16 ss
			__done = 1
		end match
	end if

	if __done = 0
		match =eax, a
			__print_reg32 eax
			__done = 1
		else match =ebx, a
			__print_reg32 ebx
			__done = 1
		else match =ecx, a
			__print_reg32 ecx
			__done = 1
		else match =edx, a
			__print_reg32 edx
			__done = 1
		else match =esi, a
			__print_reg32 esi
			__done = 1
		else match =edi, a
			__print_reg32 edi
			__done = 1
		else match =ebp, a
			__print_reg32 ebp
			__done = 1
		end match
	end if

	if __done = 0
		match [m], a
			__print_mem_char m
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
		if a eqtype 1
			__print_char a
			__done = 1
		end if
	end if

	if __done = 0
		if string? a
			local __s, __sz
			late_str __s, __sz, a
			__print_cstr __s, __sz
		else
			err 'invalid specifier'
		end if
	end if
end macro

macro print items&
	if build.debug
		iterate __it, items
			__print_one __it
		end iterate
	end if
end macro

macro print_endl
	push ax

	mov ax, 13
	call print_char16
	mov ax, 10
	call print_char16
	
	pop ax
end macro