LBF_MAGIC = 0x0046424C

LBF_TYPE_RESV = 0x0
LBF_TYPE_BIN = 0x1
LBF_TYPE_DL = 0x2
LBF_TYPE_DRV = 0x3

ST_CODE_RX = 0
ST_DATA_RO = 1
ST_DATA_RW = 2
ST_STACK_RW = 3

SF_SHAREABLE = 0x1
SF_DISCARD = 0x2
SF_RESERVED = 0xFFFC

RELOC_SEL16 = 0x1

LBF.seg_count = 0
LBF.mod_count = 0
LBF.exp_count = 0
LBF.rel_count = 0

LBF.entry_seg = 0
LBF.entry_off = 0
LBF.data_seg = 0
LBF.header_flags = LBF_TYPE_BIN

LBF.str_blob equ ""
LBF.str_size = 1

macro LBF_AddString text, ret_offset
	ret_offset = LBF.str_size

	local content
	content equ text

	LBF.str_blob equ LBF.str_blob, content, 0

	virtual at 0
		db content
		LBF.str_size = LBF.str_size + $ + 1
	end virtual
end macro

macro segment name*, type*, flags:0, align:16
	if LBF.seg_count > 0
		local _size
		_size = $

		repeat 1, num:LBF.seg_count
			load LBF.seg.data_#num : _size from 0
			LBF.seg.size_#num = _size
		end repeat

		end virtual
	end if

	LBF.seg_count = LBF.seg_count + 1
	eval 'LBF_SEG_IDX_', name, ' = LBF.seg_count - 1'

	repeat 1, num:LBF.seg_count
		LBF.seg.name_#num equ name
		LBF.seg.type_#num = type
		LBF.seg.flag_#num = flags
		LBF.seg.align_#num = align
	end repeat

	virtual at 0
end macro

macro entry label*
	LBF.entry_seg = LBF.seg_count - 1
	LBF.entry_off = label
end macro

macro data_segment
	LBF.data_seg = LBF.seg_count - 1
end macro

macro import module*, func*
	local _found, _idx, _fidx
	_found = 0

	repeat LBF.mod_count
		match =module, LBF.mod.name_#%
			_found = %
		end match
	end repeat

	if _found = 0
		LBF.mod_count = LBF.mod_count + 1
		_found = LBF.mod_count

		repeat 1, n:_found
			LBF.mod.name_#n equ module
			LBF.mod.func_count_#n = 0
		end repeat
	end if

	repeat 1, n:_found
		LBF.mod.func_count_#n = LBF.mod.func_count_#n + 1

		repeat 1, f:LBF.mod.func_count_#n
			LBF.mod.func_#n#_#f equ func

			eval func, ' equ _ipt_entry_', `n, '_', `f
		end repeat
	end repeat
end macro

macro export name*, label*
	LBF.exp_count = LBF.exp_count + 1

	repeat 1, num:LBF.exp_count
		LBF.exp.name_#num equ name
		LBF.exp.seg_#num = LBF.seg_count - 1
		LBF.exp.off_#num = label
	end repeat
end macro

macro reloc type*, target*
	local _tgt_idx

	if LBF.seg_count = 0
		err "Relocation must be inside a segment"
	end if

	eval 'if defined LBF_SEG_IDX_', target
		eval '_tgt_idx = LBF_SEG_IDX_', target
	else
		_tgt_idx = target
	end if

	LBF.rel_count = LBF.rel_count + 1

	repeat 1, num:LBF.rel_count
		LBF.rel.src_seg_#num = LBF.seg_count - 1
		LBF.rel.src_off_#num = $
		LBF.rel.tgt_seg_#num = _tgt_idx
		LBF.rel.type_#num = type
	end repeat

	if type eq RELOC_SEL16
		dw 0
	else
		dd 0
	end if
end macro

postpone
	if LBF.seg_count > 0
		_size = $

		repeat 1, num:LBF.seg_count
			load LBF.seg.data_#num : _size from 0
			LBF.seg.size_#num = _size
		end repeat

		end virtual
	end if

	org 0

	_dir_count = 1

	if LBF.mod_count > 0
		_dir_count = _dir_count + 1
	end if

	if LBF.exp_count > 0
		_dir_count = _dir_count + 1
	end if

	if LBF.rel_count > 0
		_dir_count = _dir_count + 1
	end if

	dd LBF_MAGIC
	dd LBF.header_flags
	dd LBF.entry_seg
	dd LBF.entry_off
	dd LBF.data_seg
	dd LBF.stack_size
	dd _rva_strings
	dd _dir_count

	dd _off_str_seg
	dd _rva_dir_seg

	if LBF.mod_count > 0
		dd _off_str_imp
		dd _rva_dir_imp
	end if

	if LBF.exp_count > 0
		dd _off_str_exp
		dd _rva_dir_exp
	end if

	if LBF.rel_count > 0
		dd _off_str_rel
		dd _rva_dir_rel
	end if

	$ = ($ + 3) and (not 3)
	_rva_strings = $

	db 0

	LBF_AddString 'SEGMENT', _off_str_seg
	LBF_AddString 'IMPORT', _off_str_imp
	LBF_AddString 'EXPORTS', _off_str_exp
	LBF_AddString 'RELOCS', _off_str_rel

	repeat LBF.seg_count
		LBF_AddString LBF.seg.name_#% , LBF.seg.name_off_#%
	end repeat

	repeat LBF.exp_count
		LBF_AddString LBF.exp.name_#% , LBF.exp.name_off_#%
	end repeat

	repeat LBF.mod_count, mod_idx:1
		LBF_AddString LBF.mod.name_#mod_idx , LBF.mod.name_off_#mod_idx
	
		repeat LBF.mod.func_count_#mod_idx, func_idx:1
			LBF_AddString LBF.mod.func_#mod_idx#_#func_idx, LBF.mod.func_off_#mod_idx#_#func_idx
		end repeat
	end repeat

	db LBF.str_blob

	$ = ($ + 3) and (not 3)
	_rva_dir_seg = $
	
	dd LBF.seg_count
	
	repeat LBF.seg_count
		dd LBF.seg.name_off_#%
		dd _file_off_seg_#%
		dd LBF.seg.size_#%
		dd LBF.seg.size_#%
		dd LBF.seg.type_#%
		dw LBF.seg.align_#%
		dw LBF.seg.flag_#%
	end repeat

	if LBF.mod_count > 0
		$ = ($ + 3) and (not 3)
		_rva_dir_imp = $

		dd LBF.mod_count

		repeat LBF.mod_count
			dd LBF.mod.name_off_#%
			dd _rva_ilt_#%
			dd _rva_ipt_#%
		end repeat

		repeat LBF.mod_count, mod_idx:1
			$ = ($ + 3) and (not 3)
			_rva_ilt_#mod_idx = $
			
			repeat LBF.mod.func_count_#mod_idx, func_idx:1
				dd LBF.mod.func_off_#mod_idx#_#func_idx
			end repeat
			dd 0

			$ = ($ + 3) and (not 3)
			_rva_ipt_#mod_idx = $

			repeat LBF.mod.func_count_#mod_idx, func_idx:1
				_ipt_entry_#mod_idx#_#func_idx = $ 

				dd 0
				dw 0
			end repeat
			dd 0
			dw 0

		end repeat
	end if

	if LBF.exp_count > 0
		$ = ($ + 3) and (not 3)
		_rva_dir_exp = $
		
		dd LBF.exp_count

		repeat LBF.exp_count
			dd LBF.exp.name_off_#%
			dd LBF.exp.off_#%
			dd LBF.exp.seg_#%
		end repeat
	end if

	if LBF.rel_count > 0
		$ = ($ + 3) and (not 3)
		_rva_dir_rel = $
		
		dd LBF.rel_count

		repeat LBF.rel_count
			dd LBF.rel.src_seg_#%
			dd LBF.rel.src_off_#%
			dd LBF.rel.tgt_seg_#%
			dd LBF.rel.type_#%
		end repeat
	end if

	$ = ($ + 4095) and (not 4095)
	
	repeat LBF.seg_count
		_align = LBF.seg.align_#%

		if _align = 0
			_align = 1
		end if

		while ($ mod _align) <> 0
			db 0
		end while

		_file_off_seg_#% = $

		db LBF.seg.data_#%
	end repeat
end postpone
