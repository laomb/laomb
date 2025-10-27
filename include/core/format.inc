
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
	local current
	LBF_SETTING_FLAGS = 0

	define current args:

	define LBF_HAS_KIND 0
	define LBF_HAS_VERSION 0

	while 1
		match :, current
			break
		else match =nx? more, current
			LBF_SETTING_FLAGS = LBF_F_NX_EMU
			redefine current more
		else match =relro? more, current
			LBF_SETTING_FLAGS = LBF_SETTING_FLAGS or LBF_F_RELRO
			redefine current more
		else match =safe? more, current
			LBF_SETTING_FLAGS = LBF_SETTING_FLAGS or LBF_F_SAFE_IMPORTS
			redefine current more
		else match =exe? more, current
			LBF_SETTING_KIND = 1
			redefine LBF_HAS_KIND 1
			redefine current more
		else match =drv? more, current
			LBF_SETTING_KIND = 2
			redefine LBF_HAS_KIND 1
			redefine current more
		else match =dl? more, current
			LBF_SETTING_KIND = 3
			redefine LBF_HAS_KIND 1
			redefine current more
		else
			match V more, current
				if LBF_HAS_VERSION eq 0
					define LBF_VERSION_EXPR V
					redefine LBF_HAS_VERSION 1
					redefine current more
				else
					err 'duplicate/unknown argument'
					break
				end if
			end match
		end match
	end while

	if LBF_HAS_KIND eq 0
		LBF_SETTING_KIND = 1
	end if

	if LBF_HAS_VERSION eq 0
		define LBF_VERSION_EXPR 1
	end if

	LBF_SETTING_VERSION = LBF_VERSION_EXPR
	
	include 'core/lbf.inc'
end macro
