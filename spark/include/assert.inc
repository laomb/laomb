macro __ASSERT_LOAD_TO reg?, tok&
	local __loaded
	__loaded = 0

	if x86.mode = 16
		if __loaded = 0
			match &[m], tok
				lea reg, [m]
				__loaded = 1
			end match
		end if

		if __loaded = 0
			match byte [m], tok
				movzx reg, byte [m]
				__loaded = 1
			end match
		end if

		if __loaded = 0
			match word [m], tok
				mov reg, word [m]
				__loaded = 1
			end match
		end if

		if __loaded = 0
			match [m], tok
				mov reg, word [m]
				__loaded = 1
			end match
		end if

		if __loaded = 0
			match =ax, tok
				mov reg, [bp + 26]
				__loaded = 1
			else match =bx, tok
				mov reg, [bp + 20]
				__loaded = 1
			else match =cx, tok
				mov reg, [bp + 24]
				__loaded = 1
			else match =dx, tok
				mov reg, [bp + 22]
				__loaded = 1
			else match =si, tok
				mov reg, [bp + 14]
				__loaded = 1
			else match =di, tok
				mov reg, [bp + 12]
				__loaded = 1
			else match =bp, tok
				mov reg, [bp + 16]
				__loaded = 1
			else match =sp, tok
				mov reg, [bp + 18]
				__loaded = 1
			end match

			match =cs, tok
				mov reg, [bp + 10]
				__loaded = 1
			else match =ds, tok
				mov reg, [bp + 8]
				__loaded = 1
			else match =es, tok
				mov reg, [bp + 6]
				__loaded = 1
			else match =fs, tok
				mov reg, [bp + 4]
				__loaded = 1
			else match =gs, tok
				mov reg, [bp + 2]
				__loaded = 1
			else match =ss, tok
				mov reg, [bp + 0]
				__loaded = 1
			end match
		end if

		if __loaded = 0
			if tok eqtype 1
				mov reg, tok
				__loaded = 1
			end if
		end if

	else if x86.mode = 32

		if __loaded = 0
			match &[m], tok
				lea reg, [m]
				__loaded = 1
			end match
		end if

		if __loaded = 0
			match byte [m], tok
				movzx reg, byte [m]
				__loaded = 1
			end match
		end if

		if __loaded = 0
			match word [m], tok
				movzx reg, word [m]
				__loaded = 1
			end match
		end if

		if __loaded = 0
			match [m], tok
				mov reg, dword [m]
				__loaded = 1
			end match
		end if

		if __loaded = 0
			 match =eax, tok
				mov reg, [ebp + 52]
				__loaded = 1
			else match =ebx, tok
				mov reg, [ebp + 40]
				__loaded = 1
			else match =ecx, tok
				mov reg, [ebp + 48]
				__loaded = 1
			else match =edx, tok
				mov reg, [ebp + 44]
				__loaded = 1
			else match =esi, tok
				mov reg, [ebp + 28]
				__loaded = 1
			else match =edi, tok
				mov reg, [ebp + 24]
				__loaded = 1
			else match =ebp, tok
				mov reg, [ebp + 32]
				__loaded = 1
			else match =esp, tok
				mov reg, [ebp + 36]
				__loaded = 1
			end match

			match =ax, tok
				movzx reg, word [ebp + 52]
				__loaded = 1
			else match =bx, tok
				movzx reg, word [ebp + 40]
				__loaded = 1
			else match =cx, tok
				movzx reg, word [ebp + 48]
				__loaded = 1
			else match =dx, tok
				movzx reg, word [ebp + 44]
				__loaded = 1
			else match =si, tok
				movzx reg, word [ebp + 28]
				__loaded = 1
			else match =di, tok
				movzx reg, word [ebp + 24]
				__loaded = 1
			else match =bp, tok
				movzx reg, word [ebp + 32]
				__loaded = 1
			else match =sp, tok
				movzx reg, word [ebp + 36]
				__loaded = 1
			end match

			match =cs, tok
				movzx reg, word [ebp + 20]
				__loaded = 1
			else match =ds, tok
				movzx reg, word [ebp + 16]
				__loaded = 1
			else match =es, tok
				movzx reg, word [ebp + 12]
				__loaded = 1
			else match =fs, tok
				movzx reg, word [ebp + 8]
				__loaded = 1
			else match =gs, tok
				movzx reg, word [ebp + 4]
				__loaded = 1
			else match =ss, tok
				movzx reg, word [ebp + 0]
				__loaded = 1
			end match
		end if

		if __loaded = 0
			if tok eqtype 1
				mov reg, tok
				__loaded = 1
			end if
		end if
	end if

	if __loaded = 0
		err 'assert: operand must be an immediate, GPR, or SEG register'
	end if
end macro

macro __ASSERT_EVAL __msg, one&
	local __t, __e

	if x86.mode = 16
		xor dx, dx

		match lhs =eq rhs, one
			__ASSERT_LOAD_TO ax, lhs
			__ASSERT_LOAD_TO bx, rhs
			cmp ax, bx
			je __t
		else match lhs =ne rhs, one
			__ASSERT_LOAD_TO ax, lhs
			__ASSERT_LOAD_TO bx, rhs
			cmp ax, bx
			jne __t
		else match lhs =lt rhs, one
			__ASSERT_LOAD_TO ax, lhs
			__ASSERT_LOAD_TO bx, rhs
			cmp ax, bx
			jb __t
		else match lhs =gt rhs, one
			__ASSERT_LOAD_TO ax, lhs
			__ASSERT_LOAD_TO bx, rhs
			cmp ax, bx
			ja __t
		else match lhs =lte rhs, one
			__ASSERT_LOAD_TO ax, lhs
			__ASSERT_LOAD_TO bx, rhs
			cmp ax, bx
			jbe __t
		else match lhs =gte rhs, one
			__ASSERT_LOAD_TO ax, lhs
			__ASSERT_LOAD_TO bx, rhs
			cmp ax, bx
			jae __t
		else match lhs =align rhs, one
			__ASSERT_LOAD_TO ax, lhs
			__ASSERT_LOAD_TO bx, rhs
			
			test bx, bx
			jz __e
			
			xor dx, dx
			div bx
			
			test dx, dx
			jz __t			
		else
			err 'assert: condition must be "<lhs> (eq|ne|lt|gt|lte|gte) <rhs>"'
		end match

		__e:
			add sp, 12
			popa
			popf

			push si
			mov si, __msg

			call assert_fail_rmode
		__t:
	else if x86.mode = 32
		xor edx, edx

		match lhs =eq rhs, one
			__ASSERT_LOAD_TO eax, lhs
			__ASSERT_LOAD_TO ebx, rhs
			cmp eax, ebx
			je __t
		else match lhs =ne rhs, one
			__ASSERT_LOAD_TO eax, lhs
			__ASSERT_LOAD_TO ebx, rhs
			cmp eax, ebx
			jne __t
		else match lhs =lt rhs, one
			__ASSERT_LOAD_TO eax, lhs
			__ASSERT_LOAD_TO ebx, rhs
			cmp eax, ebx
			jb __t
		else match lhs =gt rhs, one
			__ASSERT_LOAD_TO eax, lhs
			__ASSERT_LOAD_TO ebx, rhs
			cmp eax, ebx
			ja __t
		else match lhs =lte rhs, one
			__ASSERT_LOAD_TO eax, lhs
			__ASSERT_LOAD_TO ebx, rhs
			cmp eax, ebx
			jbe __t
		else match lhs =gte rhs, one
			__ASSERT_LOAD_TO eax, lhs
			__ASSERT_LOAD_TO ebx, rhs
			cmp eax, ebx
			jae __t
		else match lhs =align rhs, one
			__ASSERT_LOAD_TO eax, lhs
			__ASSERT_LOAD_TO ebx, rhs
			test ebx, ebx
			jz __e
			xor edx, edx
			div ebx
			test edx, edx
			jz __t
		else
			err 'assert: condition must be "<lhs> (eq|ne|lt|gt|lte|gte|align) <rhs>"'
		end match

		__e:
			add esp, 24
			popad
			popfd

			push esi
			mov esi, __msg

			call assert_fail_pmode
		__t:
	end if
end macro

macro __ASSERT_RESTORE
	if x86.mode = 16
		mov ax, [bp + 26]
		mov cx, [bp + 24]
		mov dx, [bp + 22]
		mov bx, [bp + 20]
		mov si, [bp + 14]
		mov di, [bp + 12]
	else if x86.mode = 32
		mov eax, [ebp + 52]
		mov ecx, [ebp + 48]
		mov edx, [ebp + 44]
		mov ebx, [ebp + 40]
		mov esi, [ebp + 28]
		mov edi, [ebp + 24]
	end if
end macro

macro assert msg, conditions&
	if build.mode = build.mode.Debug
		local __msglbl
		late_str __msglbl, msg, 0

		if x86.mode = 16
			pushf
			pusha
			push cs
			push ds
			push es
			push fs
			push gs
			push ss
			mov bp, sp
		else if x86.mode = 32
			pushfd
			pushad
			push cs
			push ds
			push es
			push fs
			push gs
			push ss
			mov ebp, esp
		end if

		iterate __one, conditions
			__ASSERT_RESTORE
			__ASSERT_EVAL __msglbl, __one
		end iterate

		if x86.mode = 16
			add sp, 12
			popa
			popf
		else if x86.mode = 32
			add esp, 24
			popad
			popfd
		end if
	end if
end macro
