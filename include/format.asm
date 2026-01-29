
calminstruction format? a*
	local type

	check $% = 0
	jyes at_bof
	err 'format must be used at the beginning of the file!'

at_bof:
	arrange a, =format a
	assemble a
end calminstruction

macro format?.lbf? args
	local current, has_kind, has_stack
	define current args:

	define has_kind 0
	define has_stack 0

	while 1
		match :, current
			break
		else match =bin? more, current
			LBF.header_flags = LBF_TYPE_BIN
			redefine has_kind 1

			redefine current more
		else match =dl? more, current
			LBF.header_flags = LBF_TYPE_DL
			redefine has_kind 1

			redefine current more
		else match =drv? more, current
			LBF.header_flags = LBF_TYPE_DRV
			redefine has_kind 1

			redefine current more
		else
			match V more, current
				LBF.stack_size = V
				redefine has_stack 1
				redefine current more
			else
				err 'unknown argument'
				break
			end match
		end match
	end while

	if has_kind eq 0
		LBF.header_flags = LBF_TYPE_BIN
	end if

	if has_stack eq 0
		LBF.stack_size = 4096
	end if

	include 'format/lbf.asm'
end macro
