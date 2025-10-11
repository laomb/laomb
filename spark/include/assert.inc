macro __ASSERT_LOAD_TO reg?, tok&
	local __loaded
	__loaded = 0

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
		if tok eqtype 1
			mov reg, tok
			__loaded = 1
		end if
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
		err 'assert: operand must be an immediate, GPR, or SEG register'
	end if
end macro

macro __ASSERT_EVAL __msg, one&
	local __t, __e
	xor dx, dx

	match lhs =eq rhs, one
		__ASSERT_LOAD_TO ax, lhs
		__ASSERT_LOAD_TO bx, rhs
		cmp ax, bx
		je __t
		jmp __e
	else match lhs =ne rhs, one
		__ASSERT_LOAD_TO ax, lhs
		__ASSERT_LOAD_TO bx, rhs
		cmp ax, bx
		jne __t
		jmp __e
	else match lhs =lt rhs, one
		__ASSERT_LOAD_TO ax, lhs
		__ASSERT_LOAD_TO bx, rhs
		cmp ax, bx
		jb __t
		jmp __e
	else match lhs =gt rhs, one
		__ASSERT_LOAD_TO ax, lhs
		__ASSERT_LOAD_TO bx, rhs
		cmp ax, bx
		ja __t
		jmp __e
	else match lhs =lte rhs, one
		__ASSERT_LOAD_TO ax, lhs
		__ASSERT_LOAD_TO bx, rhs
		cmp ax, bx
		jbe __t
		jmp __e
	else match lhs =gte rhs, one
		__ASSERT_LOAD_TO ax, lhs
		__ASSERT_LOAD_TO bx, rhs
		cmp ax, bx
		jae __t
		jmp __e
	else match lhs =align rhs, one
		__ASSERT_LOAD_TO ax, lhs
		__ASSERT_LOAD_TO bx, rhs
		
		test bx, bx
		jz __e
		
		xor dx, dx
		div bx
		
		test dx, dx
		jz __t

		jmp __e
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
end macro

macro assert msg, conditions&
	if build.mode = build.mode.Debug
		local __msglbl
		late_str __msglbl, msg, 0

		pushf
		pusha
		push cs
		push ds
		push es
		push fs
		push gs
		push ss

		iterate __one, conditions
			__ASSERT_EVAL __msglbl, __one
		end iterate

		add sp, 12
		popa
		popf
	end if
end macro
