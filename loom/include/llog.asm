
include 'fmt/helper.asm'

macro __fmt_dispatch_static txt&
	local lbl

	postpone
		segment 'DATA', ST_DATA_RW
		lbl:
			db txt
			db 0
	end postpone

	push eax ecx edx
	mov eax, lbl
	call llog$msg
	pop edx ecx eax
end macro

macro __fmt_dispatch_arg spec, arg&
	push eax ecx edx

	if arg eqtype ""
		__fmt_dispatch_static arg
	else
		match =eax, arg
		else match [m], arg
			mov eax, dword [m]
		else
			mov eax, arg
		end match

		if spec eq "d"
			call llog$dec
		else if spec eq "x"
			mov edx, 8
			call llog$hex
		else if spec eq "s"
			call llog$msg
		else
			mov edx, 8
			call llog$hex
		end if
	end if

	pop edx ecx eax
end macro

macro print pattern*, args&
	local len, i, char, next_char
	local anchor, chunk_len
	local arg_idx

	fmt__str_len len, pattern
	i = 0
	anchor = 0
	arg_idx = 0

	while i < len
		fmt__str_char_at char, i, pattern

		if char = 0x5c
			fmt__str_char_at next_char, i + 1, pattern
			if next_char = 'n'
				chunk_len = i - anchor
				if chunk_len > 0
					local txt_content_nl
					fmt__str_sub txt_content_nl, anchor, chunk_len, pattern
					__fmt_dispatch_static txt_content_nl
				end if

				__fmt_dispatch_static 10

				i = i + 2
				anchor = i
			else if next_char = 0x5c
				chunk_len = i - anchor
				if chunk_len > 0
					local txt_content_bs
					fmt__str_sub txt_content_bs, anchor, chunk_len, pattern
					__fmt_dispatch_static txt_content_bs
				end if

				__fmt_dispatch_static 0x5c

				i = i + 2
				anchor = i
			else
				i = i + 1
			end if
		else if char = '{'
			fmt__str_char_at next_char, i + 1, pattern

			if next_char = '{'
				chunk_len = i - anchor
				if chunk_len > 0
					local txt_content 
					fmt__str_sub txt_content, anchor, chunk_len, pattern
					__fmt_dispatch_static txt_content
				end if
				__fmt_dispatch_static "{"
				i = i + 2
				anchor = i
			else
				chunk_len = i - anchor
				if chunk_len > 0
					local txt_content
					fmt__str_sub txt_content, anchor, chunk_len, pattern
					__fmt_dispatch_static txt_content
				end if

				local j, spec_char, found_end
				j = i + 1
				found_end = 0
				while j < len
					fmt__str_char_at spec_char, j, pattern
					if spec_char = '}'
						found_end = 1
						break
					end if
					j = j + 1
				end while

				if ~ found_end
					err "fmt: missing closing brace"
				end if

				local specifier
				fmt__str_sub specifier, i + 1, (j - i - 1), pattern

				local iter_arg
				fmt__arg_at iter_arg, arg_idx, args
				__fmt_dispatch_arg specifier, iter_arg

				arg_idx = arg_idx + 1
				i = j + 1
				anchor = i
			end if
		else
			i = i + 1
		end if
	end while

	chunk_len = len - anchor
	if chunk_len > 0
		local final_chunk
		fmt__str_sub final_chunk, anchor, chunk_len, pattern
		__fmt_dispatch_static final_chunk
	end if
end macro

