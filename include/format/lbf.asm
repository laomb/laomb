LBF_MAGIC = 0x0046424C

LBF_TYPE_RESV = 0x0
LBF_TYPE_BIN = 0x1
LBF_TYPE_DL = 0x2
LBF_TYPE_DRV = 0x3

ST_CODE_RX = 0
ST_DATA_RO = 1
ST_DATA_RW = 2
OTHER_RW = 3

SF_SHAREABLE = 0x1
SF_DISCARD = 0x2
SF_RESERVED = 0xFFFC

RELOC_SEL16 = 0x1

LBF.cur_seg = -1
LBF.seg_count = 0
LBF.mod_count = 0
LBF.exp_count = 0
LBF.rel_count = 0

LBF.entry_seg = 0
LBF.entry_off = 0
LBF.data_seg = 0
LBF.header_flags = LBF_TYPE_BIN

LBF.string_pos = 1
virtual at 0
	LBFStringBlob:: rb LBF.string_size
end virtual
store 0 at LBFStringBlob:0

macro LBF_AddString text, ret_offset
	local __str

	ret_offset = LBF.string_pos
	__str equ text

	store __str : lengthof (string __str) at LBFStringBlob:LBF.string_pos
	LBF.string_pos = LBF.string_pos + lengthof (string __str)
	store 0 at LBFStringBlob:LBF.string_pos
	LBF.string_pos = LBF.string_pos + 1
end macro

macro segment name*, type*, flags:0, align:16
	local _found, _is_new, _size

	if LBF.cur_seg >= 0
		_size:

		repeat 1, num:LBF.cur_seg + 1
			load LBF.seg.data_#num : _size from 0
			LBF.seg.size_#num = _size
			LBF.seg.init_#num = 1
		end repeat

		end virtual
	end if

	_found = 0
	repeat LBF.seg_count, i:1
		match =name, LBF.seg.name_#i
			_found = i
		end match
	end repeat

	_is_new = 0
	if _found = 0
		LBF.seg_count = LBF.seg_count + 1
		_found = LBF.seg_count
		_is_new = 1
		eval 'LBF_SEG_IDX_', name, ' = _found - 1'
	end if

	LBF.cur_seg = _found - 1

	repeat 1, num:_found
		if _is_new
			LBF.seg.init_#num = 0
		end if

		LBF.seg.name_#num equ name
		LBF.seg.type_#num = type
		LBF.seg.flag_#num = flags
		LBF.seg.align_#num = align
	end repeat

	virtual at 0
		repeat 1, num:_found
			if LBF.seg.init_#num
				db LBF.seg.data_#num
			end if
		end repeat
end macro

macro entry label*
	if LBF.cur_seg < 0
		err "entry must be inside a segment"
	end if

	LBF.entry_seg = LBF.cur_seg
	LBF.entry_off = label
end macro

macro data_segment
	if LBF.cur_seg < 0
		err "data_segment must be inside a segment"
	end if

	LBF.data_seg = LBF.cur_seg
end macro

macro import module*, func*
	local _found
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
		end repeat
	end repeat
end macro

macro export name*, label*
	if LBF.cur_seg < 0
		err "export must be inside a segment"
	end if

	LBF.exp_count = LBF.exp_count + 1
	repeat 1, num:LBF.exp_count
		LBF.exp.name_#num equ name
		LBF.exp.seg_#num = LBF.cur_seg
		LBF.exp.off_#num = label
	end repeat
end macro

calminstruction __x86_mov? dest*, src*
	call mov, dest, src
end calminstruction

calminstruction mov? dest*, src*
	local target, cmd

	match =rel? target, src
	jyes handling_reloc

	call __x86_mov, dest, src
	exit

handling_reloc:
	call x86.parse_operand@dest, dest
	check @dest.type = 'reg' & @dest.size = 2
	jno invalid_operand

	check x86.mode = 16
	jyes no_prefix

	emit 1, 0x66
no_prefix:
	emit 1, 0xB8 + @dest.rm

	arrange cmd, =reloc =RELOC_SEL16, target
	assemble cmd
	exit

invalid_operand:
	err "invalid operand size; Segment relocation is 16-bit"
	exit
end calminstruction

macro reloc type*, target*
	local _tgt_idx

	if LBF.cur_seg < 0
		err "relocation must be inside a segment"
	end if

	eval 'if defined LBF_SEG_IDX_', target
		eval '_tgt_idx = LBF_SEG_IDX_', target
	else
		_tgt_idx = target
	end if

	LBF.rel_count = LBF.rel_count + 1
	repeat 1, num:LBF.rel_count
		LBF.rel.src_seg_#num = LBF.cur_seg
		LBF.rel.src_off_#num:
		LBF.rel.tgt_seg_#num = _tgt_idx
		LBF.rel.type_#num = type
	end repeat

	if type eq RELOC_SEL16
		dw 0
	else
		err "unkown relocation type"
	end if
end macro

postpone
	if LBF.seg_count > 0
		_size:

		repeat 1, num:LBF.seg_count
			load LBF.seg.data_#num : _size from 0
			LBF.seg.size_#num = _size
		end repeat

		end virtual
	end if

	if LBF.mod_count > 0
		LBF.seg_count = LBF.seg_count + 1
		LBF.ipt_seg_num = LBF.seg_count

		LBF_SEG_IDX_IPT = LBF.ipt_seg_num - 1

		repeat 1, num:LBF.ipt_seg_num
			LBF.seg.init_#num = 1
			LBF.seg.name_#num equ 'IPT'
			LBF.seg.type_#num = ST_DATA_RW
			LBF.seg.flag_#num = 0
			LBF.seg.align_#num = 4
		end repeat

		virtual at 0
			_ipt_cursor = 0

			repeat LBF.mod_count, mod_idx:1
				while (_ipt_cursor and 3) <> 0
					db 0
					_ipt_cursor = _ipt_cursor + 1
				end while
				LBF.ipt.mod_off_#mod_idx = _ipt_cursor

				repeat LBF.mod.func_count_#mod_idx, func_idx:1
					eval LBF.mod.func_#mod_idx#_#func_idx, ' = _ipt_cursor'
					dd 0
					dw 0
					_ipt_cursor = _ipt_cursor + 6
				end repeat

				dd 0
				dw 0
				_ipt_cursor = _ipt_cursor + 6
			end repeat

			_ipt_size = _ipt_cursor
			repeat 1, num:LBF.ipt_seg_num
				load LBF.seg.data_#num : _ipt_size from 0
			end repeat
		end virtual

		repeat 1, num:LBF.ipt_seg_num
			LBF.seg.size_#num = _ipt_size
		end repeat

		repeat 1, num:LBF.ipt_seg_num
			LBF_IPT_BASE equ _file_off_seg_#num
		end repeat

		repeat LBF.mod_count, mod_idx:1
			_rva_ipt_#mod_idx equ LBF_IPT_BASE + LBF.ipt.mod_off_#mod_idx
		end repeat
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
	_rva_strings:

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

	LBF.string_size := LBF.string_pos
	load __strbytes : LBF.string_size from LBFStringBlob:0
	db __strbytes

	$ = ($ + 3) and (not 3)
	_rva_dir_seg:
	
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
		_rva_dir_imp:

		dd LBF.mod_count

		repeat LBF.mod_count
			dd LBF.mod.name_off_#%
			dd _rva_ilt_#%
			dd _rva_ipt_#%
		end repeat

		repeat LBF.mod_count, mod_idx:1
			$ = ($ + 3) and (not 3)
			_rva_ilt_#mod_idx:
			
			repeat LBF.mod.func_count_#mod_idx, func_idx:1
				dd LBF.mod.func_off_#mod_idx#_#func_idx
			end repeat
			dd 0
		end repeat
	end if

	if LBF.exp_count > 0
		$ = ($ + 3) and (not 3)
		_rva_dir_exp:
		
		dd LBF.exp_count

		repeat LBF.exp_count
			dd LBF.exp.name_off_#%
			dd LBF.exp.off_#%
			dd LBF.exp.seg_#%
		end repeat
	end if

	if LBF.rel_count > 0
		$ = ($ + 3) and (not 3)
		_rva_dir_rel:
		
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

		_file_off_seg_#%:

		db LBF.seg.data_#%
	end repeat
end postpone
