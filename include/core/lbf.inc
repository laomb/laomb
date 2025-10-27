; TODO reopenable sections (and segments)

LBF_MAGIC = 0x1A4C4246
LBF_I386 = 3

LBF_F_NX_EMU = 1 shl 0
LBF_F_SAFE_IMPORTS = 1 shl 2

LBF_EXE = 1
LBF_DRV = 2
LBF_DL = 3

LBF_T_SEGMENTS = 1
LBF_T_SECTIONS = 2
LBF_T_RELOCS = 3
LBF_T_EXPORTS = 4
LBF_T_DEPS = 5
LBF_T_TLS = 6
LBF_T_SECURITY = 7
LBF_T_STRTAB = 8
LBF_T_IMPORTS = 9
LBF_T_SYMIDX = 10
LBF_T_SYMSTR = 11

LBF_ST_CODE_RX = 1
LBF_ST_DATA_RW = 3
LBF_ST_DATA_RO = 4
LBF_ST_STACK_RW = 5

LBF_SF_SHAREABLE = 1 shl 0
LBF_SF_INIT_ONCE = 1 shl 1

LBF_SK_TEXT = 1
LBF_SK_RODATA = 2
LBF_SK_DATA = 3
LBF_SK_BSS = 4
LBF_SK_TLS = 5
LBF_SK_STUB = 6
LBF_SK_OTHER = 7

LBF_CF_DISCARDABLE = 1 shl 0
LBF_CF_ZERO_INIT = 1 shl 1

LBF_IF_BYORD = 1 shl 0
LBF_IF_GATE = 1 shl 1
LBF_IF_PRIVATE = 1 shl 2

LBF_RELOCS_FARPTR32 = 1
LBF_RELOCS_SEL16 = 2

LBF_RF_EXTERNAL = 0
LBF_RF_SELF_IMPORT = 1

LBF_SIGALG_SHA256 = 3
LBF_SIG_SIZE = 32

macro struct? name
	macro end?.struct?!
		end namespace
		esc end struc
		virtual at 0
		name name
		sizeof.name = $
		end virtual
		purge end?.struct?
	end macro

	esc struc name
		label . : sizeof.name
		namespace .
end macro

struct LBFHeader
	magic dd ?
	version dd ?
	abi_major dw ?
	abi_minor dw ?
	kind dw ?
	machine dw ?
	flags dd ?
	entry_sel dw ?
	data_sel dw ?
	entry_off dd ?
	n_tables dd ?
	dir_off dd ?
end struct

struct LBFDirEnt
	type dw ?
	reserved dw ?
	offset dd ?
	size dd ?
	count dd ?
end struct

struct LBFSegDesc
	seg_index dw ?
	typ db ?
	reserved db ?
	vlimit dd ?
	alignment dd ?
	sect_start dd ?
	sect_count dd ?
	flags dd ?
end struct

struct LBFSection
	name dd ?
	seg_index dw ?
	sect_kind dw ?
	file_off dd ?
	file_sz dd ?
	mem_off dd ?
	mem_sz dd ?
	align dd ?
	flags dd ?
end struct

struct LBFDependency
	name_off dd ?
	min_ver dd ?
end struct

struct LBFImportDesc
	dep_index dd ?
	name_off dd ?
	hint dd ?
	flags dd ?
end struct

struct LBFRELOCSEntry
	seg_index dw ?
	kind dw ?
	slot_off dd ?
	import_ix dd ?
	flags dd ?
end struct

struct LBFExport
	name_off dd ?
	ordinal dd ?
	seg_index dw ?
	reserved dw ?
	value dd ?
	flags dd ?
end struct

struct SIdxPHeader
	seg_index dw ?
	flags dw ?
	part_size dd ?
	next_link dd ?
end struct

struct SStrPHeader
	seg_index dw ?
	flags dw ?
	part_size dd ?
	next_link dd ?
end struct

struct LBFSecurity
	alg_id dd ?
	data_off dd ?
	data_sz dd ?
	flags dd ?
end struct

struct LBFSSSegDesc
	alignment dd ?
	file_base dd ?
end struct

struct LBFSSSecDesc
	seg_index dd ?
	start_off dd ?
	end_off dd ?
end struct

purge struct?

if ~ defined LBF_SETTING_FLAGS
	LBF_SETTING_FLAGS = 0
end if
if ~ defined LBF_SETTING_KIND
	LBF_SETTING_KIND = LBF_EXE
end if
if ~ defined LBF_SETTING_VERSION
	LBF_SETTING_VERSION = 1
end if

ABI_MAJOR = 1
ABI_MINOR = 0

SEG_COUNT = 0
SEC_COUNT = 0
DEP_COUNT = 0
IMP_COUNT = 0
REL_COUNT = 0
EXP_COUNT = 0

CURRENT_SEG_DEFINED = 0
CURRENT_SEC_ACTIVE = 0
CURRENT_SEG_INDEX = 0
CURRENT_SEC_INDEX = 0
CURRENT_SEG_MEMTOP = 0
CURRENT_SEC_MEMOFF = 0
CURRENT_SEC_ALIGN = 1

ENTRY_SEL = 0
ENTRY_OFF = 0
DATA_SEL = 0

if ~ defined __ENTRY_SET
	__ENTRY_SET = 0
end if

virtual at 0
	header_area::
	db sizeof.LBFHeader dup 0
end virtual

virtual at 0
	dir_table:: rb DIR_SIZE
end virtual

virtual at 0
	seg_table:: rb SEG_TABLE_SIZE
end virtual

virtual at 0
	sec_table:: rb SEC_TABLE_SIZE
end virtual

virtual at 0
	dep_table:: rb DEP_TABLE_SIZE
end virtual

virtual at 0
	imp_table:: rb IMP_TABLE_SIZE
end virtual

virtual at 0
	reloc_table:: rb RELOC_TABLE_SIZE
end virtual

virtual at 0
	export_table:: rb EXPORT_TABLE_SIZE
end virtual

SECURITY_TABLE_SIZE := sizeof.LBFSecurity + LBF_SIG_SIZE
virtual at 0
	security_table:: rb SECURITY_TABLE_SIZE
end virtual

STRTAB_POS = 1
virtual at 0
	strtab:: rb STRTAB_SIZE
end virtual
store 0 at strtab:0

virtual at 0
	symidx_table:: rb SYMIDX_SIZE
end virtual

virtual at 0
	symstr_table:: rb SYMSTR_SIZE
end virtual

virtual at 0
	segdesc_table:: rb SEGDESC_SIZE
end virtual

virtual at 0
	secemit_table:: rb SECEMIT_SIZE
end virtual

store LBF_MAGIC at header_area : LBFHeader.magic
store LBF_SETTING_VERSION at header_area : LBFHeader.version
store ABI_MAJOR at header_area : LBFHeader.abi_major
store ABI_MINOR at header_area : LBFHeader.abi_minor
store LBF_SETTING_KIND at header_area : LBFHeader.kind
store LBF_I386 at header_area : LBFHeader.machine
store LBF_SETTING_FLAGS at header_area : LBFHeader.flags
store F_ENTRY_SEL at header_area : LBFHeader.entry_sel
store F_DATA_SEL at header_area : LBFHeader.data_sel
store F_ENTRY_OFF at header_area : LBFHeader.entry_off
store N_TABLES at header_area : LBFHeader.n_tables
store DIR_OFF at header_area : LBFHeader.dir_off

store LBF_SIGALG_SHA256 at security_table : LBFSecurity.alg_id
store sizeof.LBFSecurity at security_table : LBFSecurity.data_off
store LBF_SIG_SIZE at security_table : LBFSecurity.data_sz
store 0 at security_table : LBFSecurity.flags

load __hbytes : sizeof.LBFHeader from header_area:0
db __hbytes

macro __strtab_add ret, s
	local __off
	__off = STRTAB_POS
	__txt equ `s

	store __txt : lengthof (string __txt) at strtab:STRTAB_POS
	STRTAB_POS = STRTAB_POS + lengthof (string __txt)
	store 0 at strtab:STRTAB_POS
	STRTAB_POS = STRTAB_POS + 1
	ret = __off
end macro

macro __seg_ord_from token, out
	match =., token
	end match
	match any, token
		out = LBF.SEGORD.#any
	end match
end macro

macro segment name*, type*, vlm:0x10000, alg:4, flg:0
	end segment

	SEG_INDEX = SEG_COUNT
	SEG_COUNT = SEG_COUNT + 1
	CURRENT_SEG_INDEX = SEG_INDEX
	CURRENT_SEG_DEFINED = 1
	CURRENT_SEG_MEMTOP = 0

	define LBF.SEGORD.#name SEG_INDEX

	virtual at 0
		repeat 1, vIndex:SEG_INDEX
			SEG_LABEL_#vIndex::
		end repeat

		store SEG_INDEX at seg_table : SEG_INDEX * sizeof.LBFSegDesc + LBFSegDesc.seg_index
		store type at seg_table : SEG_INDEX * sizeof.LBFSegDesc + LBFSegDesc.typ
		store 0 at seg_table : SEG_INDEX * sizeof.LBFSegDesc + LBFSegDesc.reserved
		store vlm at seg_table : SEG_INDEX * sizeof.LBFSegDesc + LBFSegDesc.vlimit
		store alg at seg_table : SEG_INDEX * sizeof.LBFSegDesc + LBFSegDesc.alignment
		store SEC_COUNT at seg_table : SEG_INDEX * sizeof.LBFSegDesc + LBFSegDesc.sect_start
		store 0 at seg_table : SEG_INDEX * sizeof.LBFSegDesc + LBFSegDesc.sect_count
		store flg at seg_table : SEG_INDEX * sizeof.LBFSegDesc + LBFSegDesc.flags

		store alg at segdesc_table : SEG_INDEX * sizeof.LBFSSSegDesc + LBFSSSegDesc.alignment
		store 0 at segdesc_table : SEG_INDEX * sizeof.LBFSSSegDesc + LBFSSSegDesc.file_base
end macro

macro end?.segment
	end section

	if CURRENT_SEG_DEFINED <> 0
		local __start
		load __start dword from seg_table : CURRENT_SEG_INDEX * sizeof.LBFSegDesc + LBFSegDesc.sect_start
		store (SEC_COUNT - __start) at seg_table : CURRENT_SEG_INDEX * sizeof.LBFSegDesc + LBFSegDesc.sect_count

		end virtual

		CURRENT_SEG_DEFINED = 0
	end if
end macro

macro section nm*, kind*, algn:4, flg:0
	CURRENT_SEC_FILE_BEGIN = $%%
	CURRENT_SEC_ALIGN = algn

	local __name_off
	__strtab_add __name_off, nm

	SEC_INDEX = SEC_COUNT
	SEC_COUNT = SEC_COUNT + 1
	CURRENT_SEC_INDEX = SEC_INDEX
	CURRENT_SEC_ACTIVE = 1

	local __memoff
	__memoff = ((CURRENT_SEG_MEMTOP + (algn-1)) and (not (algn-1)))
	CURRENT_SEC_MEMOFF = __memoff

	store __name_off at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.name
	store CURRENT_SEG_INDEX at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.seg_index
	store kind at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.sect_kind
	store 0 at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.file_off
	store 0 at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.file_sz
	store CURRENT_SEC_MEMOFF at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.mem_off
	store 0 at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.mem_sz
	store algn at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.align
	store flg at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.flags

	store CURRENT_SEG_INDEX at secemit_table : SEC_INDEX * sizeof.LBFSSSecDesc + LBFSSSecDesc.seg_index
	store CURRENT_SEC_MEMOFF at secemit_table : SEC_INDEX * sizeof.LBFSSSecDesc + LBFSSSecDesc.start_off
	store CURRENT_SEC_MEMOFF at secemit_table : SEC_INDEX * sizeof.LBFSSSecDesc + LBFSSSecDesc.end_off
end macro

macro end?.section
	if CURRENT_SEC_ACTIVE <> 0
		local __sec_end, __memsz, __align

		load __align from sec_table : CURRENT_SEC_INDEX * sizeof.LBFSection + LBFSection.align

		__sec_end = CURRENT_SEC_MEMOFF + ($% - CURRENT_SEC_MEMOFF)
		__padded_end = ((__sec_end + (__align - 1)) and (not (__align - 1)))
		__memsz = __padded_end - CURRENT_SEC_MEMOFF

		store __memsz at sec_table : CURRENT_SEC_INDEX * sizeof.LBFSection + LBFSection.mem_sz
		store __padded_end at secemit_table : CURRENT_SEC_INDEX * sizeof.LBFSSSecDesc + LBFSSSecDesc.end_off

		if __padded_end > CURRENT_SEG_MEMTOP
			CURRENT_SEG_MEMTOP = __padded_end
		end if

		CURRENT_SEC_ACTIVE = 0
	end if
end macro

macro bss nm*, sz*, algn:4, flg:LBF_CF_ZERO_INIT
	if CURRENT_SEG_DEFINED = 0
		err 'bss: must be inside segment'
	end if
	if CURRENT_SEC_ACTIVE <> 0
		err 'bss: cannot open bss while another section is active'
	end if

	local __memoff
	__memoff = ((CURRENT_SEG_MEMTOP + (algn-1)) and (not (algn-1)))

	local __name_off
	__strtab_add __name_off, nm

	SEC_INDEX = SEC_COUNT
	SEC_COUNT = SEC_COUNT + 1

	store __name_off at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.name
	store CURRENT_SEG_INDEX at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.seg_index
	store LBF_SK_BSS at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.sect_kind
	store 0 at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.file_off
	store 0 at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.file_sz
	store __memoff at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.mem_off
	store sz at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.mem_sz
	store algn at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.align
	store flg at sec_table : SEC_INDEX * sizeof.LBFSection + LBFSection.flags

	store CURRENT_SEG_INDEX at secemit_table : SEC_INDEX * sizeof.LBFSSSecDesc + LBFSSSecDesc.seg_index
	store 0 at secemit_table : SEC_INDEX * sizeof.LBFSSSecDesc + LBFSSSecDesc.start_off
	store 0 at secemit_table : SEC_INDEX * sizeof.LBFSSSecDesc + LBFSSSecDesc.end_off

	CURRENT_SEG_MEMTOP = __memoff + sz
end macro

macro dep module, mv:0
	local __name_off
	__strtab_add __name_off, module
	store __name_off at dep_table : DEP_COUNT * sizeof.LBFDependency + LBFDependency.name_off
	store mv at dep_table : DEP_COUNT * sizeof.LBFDependency + LBFDependency.min_ver
	LBF.DEPORD.#module = DEP_COUNT
	DEP_COUNT = DEP_COUNT + 1
end macro

macro import module*, name*, flg:0, byord:0
	match any, LBF.DEPORD.#module
		__depix = LBF.DEPORD.#module
	else
		dep module, 0
		__depix = DEP_COUNT - 1
	end match

	local __name_off
	if (flg and LBF_IF_BYORD) <> 0
		__name_off = 0
	else
		__strtab_add __name_off, name
	end if

	store __depix at imp_table : IMP_COUNT * sizeof.LBFImportDesc + LBFImportDesc.dep_index
	store __name_off at imp_table : IMP_COUNT * sizeof.LBFImportDesc + LBFImportDesc.name_off
	store byord at imp_table : IMP_COUNT * sizeof.LBFImportDesc + LBFImportDesc.hint
	store flg at imp_table : IMP_COUNT * sizeof.LBFImportDesc + LBFImportDesc.flags

	IMP.#module.#name = IMP_COUNT

	IMP_COUNT = IMP_COUNT + 1
end macro

macro export label, ord:0
	if CURRENT_SEC_ACTIVE = 0
		err 'export: must be inside active section'
	end if

	local segi, baseoff, __name_off
	segi = CURRENT_SEG_INDEX
	baseoff = $%

	__strtab_add __name_off, label

	store __name_off at export_table : EXP_COUNT * sizeof.LBFExport + LBFExport.name_off
	store ord at export_table : EXP_COUNT * sizeof.LBFExport + LBFExport.ordinal
	store segi at export_table : EXP_COUNT * sizeof.LBFExport + LBFExport.seg_index
	store 0 at export_table : EXP_COUNT * sizeof.LBFExport + LBFExport.reserved
	store baseoff at export_table : EXP_COUNT * sizeof.LBFExport + LBFExport.value
	store 0 at export_table : EXP_COUNT * sizeof.LBFExport + LBFExport.flags

	EXP_COUNT = EXP_COUNT + 1
end macro

macro entry lbl
	if CURRENT_SEG_DEFINED = 0
		err 'entry: must be used inside an active segment'
	end if
	if __ENTRY_SET <> 0
		err 'entry: entry point already set'
	end if

	ENTRY_SEL = CURRENT_SEG_INDEX
	ENTRY_OFF = $%

	__ENTRY_SET = 1
end macro

macro __slot_off out
	if CURRENT_SEC_ACTIVE = 0
		err 'reloc slot must be inside an active section'
	end if
	out = $%
end macro

macro reloc flg, knd, target
	if CURRENT_SEC_ACTIVE = 0
		err 'reloc: must be inside an active section'
	end if

	local __slot_off_val
	__slot_off __slot_off_val

	local __import_ix

	if flg = LBF_RF_EXTERNAL
		match mod . sym, target
			__import_ix = IMP.mod.sym
		else
			err 'reloc: external needs module.symbol target'
		end match
	else if flg = LBF_RF_SELF_IMPORT
		if knd <> LBF_RELOCS_SEL16
			err 'reloc: SELF_IMPORT only valid with LBF_RELOCS_SEL16'
		end if

		local __seg_ord
		__seg_ord_from target, __seg_ord
		__import_ix = __seg_ord and 0xFFFF
	else
		err 'reloc: unknown flags mode'
	end if

	if knd = LBF_RELOCS_FARPTR32
		db 0,0,0,0,0,0
	else if knd = LBF_RELOCS_SEL16
		db 0,0
	else
		err 'reloc: unknown reloc kind'
	end if

	store CURRENT_SEG_INDEX at reloc_table : REL_COUNT * sizeof.LBFRELOCSEntry + LBFRELOCSEntry.seg_index
	store knd at reloc_table : REL_COUNT * sizeof.LBFRELOCSEntry + LBFRELOCSEntry.kind
	store __slot_off_val at reloc_table : REL_COUNT * sizeof.LBFRELOCSEntry + LBFRELOCSEntry.slot_off
	store __import_ix at reloc_table : REL_COUNT * sizeof.LBFRELOCSEntry + LBFRELOCSEntry.import_ix
	store flg at reloc_table : REL_COUNT * sizeof.LBFRELOCSEntry + LBFRELOCSEntry.flags

	REL_COUNT = REL_COUNT + 1
end macro

macro data.from seg
	match any, seg
		local ord
		__seg_ord_from seg, ord
		DATA_SEL = ord
	end match
end macro

macro reloc flg, knd, target
	if CURRENT_SEC_ACTIVE = 0
		err 'reloc: must be inside an active section'
	end if

	local __slot_off_val
	__slot_off __slot_off_val

	local __import_ix

	if flg = LBF_RF_EXTERNAL
		match mod . sym, target
			__import_ix = IMP.mod.sym
		else
			err 'reloc: external needs module.symbol target'
		end match
	else if flg = LBF_RF_SELF_IMPORT
		if knd <> LBF_RELOCS_SEL16
			err 'reloc: SELF_IMPORT only valid with LBF_RELOCS_SEL16'
		end if

		local __seg_ord
		__seg_ord_from target, __seg_ord
		__import_ix = __seg_ord and 0xFFFF
	else
		err 'reloc: unknown flags mode'
	end if

	if knd = LBF_RELOCS_FARPTR32
		db 0,0,0,0,0,0
	else if knd = LBF_RELOCS_SEL16
		db 0,0
	else
		err 'reloc: unknown reloc kind'
	end if

	store CURRENT_SEG_INDEX at reloc_table : REL_COUNT * sizeof.LBFRELOCSEntry + LBFRELOCSEntry.seg_index
	store knd at reloc_table : REL_COUNT * sizeof.LBFRELOCSEntry + LBFRELOCSEntry.kind
	store __slot_off_val at reloc_table : REL_COUNT * sizeof.LBFRELOCSEntry + LBFRELOCSEntry.slot_off
	store __import_ix at reloc_table : REL_COUNT * sizeof.LBFRELOCSEntry + LBFRELOCSEntry.import_ix
	store flg at reloc_table : REL_COUNT * sizeof.LBFRELOCSEntry + LBFRELOCSEntry.flags

	REL_COUNT = REL_COUNT + 1
end macro

postpone
	end segment

	repeat SEG_COUNT
		__SEG_I = %-1

		load __ALIGN dword from segdesc_table : __SEG_I * sizeof.LBFSSSegDesc + LBFSSSegDesc.alignment

		__FILE_BASE = $%
        store __FILE_BASE at segdesc_table : __SEG_I * sizeof.LBFSSSegDesc + LBFSSSegDesc.file_base

		repeat 1, vIndex:__SEG_I
			load __segbytes : sizeof SEG_LABEL_#vIndex from SEG_LABEL_#vIndex:0
		end repeat
        db __segbytes
	end repeat

	repeat SEC_COUNT
		__SEC_I = %-1

		load __KIND word from sec_table : __SEC_I * sizeof.LBFSection + LBFSection.sect_kind

		if __KIND <> LBF_SK_BSS
            load __SEG_IDX dword from secemit_table : __SEC_I * sizeof.LBFSSSecDesc + LBFSSSecDesc.seg_index
            load __START dword from secemit_table : __SEC_I * sizeof.LBFSSSecDesc + LBFSSSecDesc.start_off
            load __END dword from secemit_table : __SEC_I * sizeof.LBFSSSecDesc + LBFSSSecDesc.end_off

            __SIZE = __END - __START

            load __SEG_BASE dword from segdesc_table : __SEG_IDX * sizeof.LBFSSSegDesc + LBFSSSegDesc.file_base

            __FILE_OFF = __SEG_BASE + __START

            store __FILE_OFF at sec_table : __SEC_I * sizeof.LBFSection + LBFSection.file_off
            store __SIZE at sec_table : __SEC_I * sizeof.LBFSection + LBFSection.file_sz
        end if
	end repeat

	SEG_TABLE_SIZE := SEG_COUNT * sizeof.LBFSegDesc
	SEC_TABLE_SIZE := SEC_COUNT * sizeof.LBFSection
	DEP_TABLE_SIZE := DEP_COUNT * sizeof.LBFDependency
	IMP_TABLE_SIZE := IMP_COUNT * sizeof.LBFImportDesc
	RELOC_TABLE_SIZE:= REL_COUNT * sizeof.LBFRELOCSEntry
	EXPORT_TABLE_SIZE := EXP_COUNT * sizeof.LBFExport
	STRTAB_SIZE := STRTAB_POS
	SYMIDX_SIZE := 0
	SYMSTR_SIZE := 0

	DIR_COUNT = 0

	macro __emit_table ttype, buf, bsize, countval
		if bsize > 0
			local off
			off = $%
			load __bytes : bsize from buf:0
			db __bytes
			store ttype at dir_table : DIR_COUNT * sizeof.LBFDirEnt + LBFDirEnt.type
			store 0 at dir_table : DIR_COUNT * sizeof.LBFDirEnt + LBFDirEnt.reserved
			store off at dir_table : DIR_COUNT * sizeof.LBFDirEnt + LBFDirEnt.offset
			store bsize at dir_table : DIR_COUNT * sizeof.LBFDirEnt + LBFDirEnt.size
			store countval at dir_table : DIR_COUNT * sizeof.LBFDirEnt + LBFDirEnt.count
			DIR_COUNT = DIR_COUNT + 1
		end if
	end macro

	__emit_table LBF_T_SEGMENTS, seg_table, SEG_TABLE_SIZE, SEG_COUNT
	__emit_table LBF_T_SECTIONS, sec_table, SEC_TABLE_SIZE, SEC_COUNT
	__emit_table LBF_T_RELOCS, reloc_table, RELOC_TABLE_SIZE, REL_COUNT
	__emit_table LBF_T_EXPORTS, export_table, EXPORT_TABLE_SIZE, EXP_COUNT
	__emit_table LBF_T_DEPS, dep_table, DEP_TABLE_SIZE, DEP_COUNT
	__emit_table LBF_T_IMPORTS, imp_table, IMP_TABLE_SIZE, IMP_COUNT
	__emit_table LBF_T_SECURITY, security_table, SECURITY_TABLE_SIZE, 0
	__emit_table LBF_T_STRTAB, strtab, STRTAB_SIZE, 0
	__emit_table LBF_T_SYMIDX, symidx_table, SYMIDX_SIZE, 0
	__emit_table LBF_T_SYMSTR, symstr_table, SYMSTR_SIZE, 0

	DIR_OFF = $%
	DIR_SIZE = DIR_COUNT * sizeof.LBFDirEnt
	load __dirbytes : DIR_SIZE from dir_table:0
	db __dirbytes

	N_TABLES := DIR_COUNT
	F_ENTRY_SEL = ENTRY_SEL
	F_ENTRY_OFF = ENTRY_OFF
	F_DATA_SEL = DATA_SEL

	SEGDESC_SIZE := SEG_COUNT * sizeof.LBFSSSegDesc
	SECEMIT_SIZE := SEC_COUNT * sizeof.LBFSSSecDesc
end postpone

postpone ?
	__SEC_OFF = 0

	repeat N_TABLES
		__DIRENT_OFF = DIR_OFF + (%-1) * sizeof.LBFDirEnt

		load __TTYPE word from __DIRENT_OFF + LBFDirEnt.type
		load __TOFFSET dword from __DIRENT_OFF + LBFDirEnt.offset

		if __TTYPE = LBF_T_SECURITY
			__SEC_OFF = __TOFFSET
		end if
	end repeat

	__FILE_SIZE = $%
	__SIG_PAYLOAD_OFF = sizeof.LBFSecurity
	__SIG_START = __SEC_OFF + __SIG_PAYLOAD_OFF
	__SIG_END = __SIG_START + LBF_SIG_SIZE

	__PART1_LEN = __SIG_START
	__PART2_LEN = __FILE_SIZE - __SIG_END
	__MSG_LEN = __PART1_LEN + __PART2_LEN

	__TMP_MOD = (__MSG_LEN + 1 + 8) and 63
	__PAD_ZEROS = (64 - __TMP_MOD) and 63
	__PADDED_LEN = __MSG_LEN + 1 + __PAD_ZEROS + 8
	__NUM_BLOCKS = __PADDED_LEN / 64

	__BITLEN_LO = ((__MSG_LEN shl 3) and 0xFFFFFFFF)
	__BITLEN_HI = (__MSG_LEN shr 29) and 0xFFFFFFFF

	virtual at 0
		__PAD_BUF:: rb __PADDED_LEN
		__SHA_W:: rb 64 * 4
		__SHA_K:: rb 64 * 4
	end virtual

	if __PART1_LEN > 0
		repeat __PART1_LEN
			__i = % - 1
			load __b byte from __i
			store byte __b at __PAD_BUF:__i
		end repeat
	end if

	if __PART2_LEN > 0
		repeat __PART2_LEN
			__i2 = % - 1
			__src = __SIG_END + __i2
			__dst = __PART1_LEN + __i2
			load __b2 byte from __src
			store byte __b2 at __PAD_BUF:__dst
		end repeat
	end if

	store byte 0x80 at __PAD_BUF:__MSG_LEN

	repeat __PAD_ZEROS
		store byte 0 at __PAD_BUF:(__MSG_LEN + 1 + (% - 1))
	end repeat

	__LEN_POS = __MSG_LEN + 1 + __PAD_ZEROS
	store byte ((__BITLEN_HI shr 24) and 0xFF) at __PAD_BUF:(__LEN_POS + 0)
	store byte ((__BITLEN_HI shr 16) and 0xFF) at __PAD_BUF:(__LEN_POS + 1)
	store byte ((__BITLEN_HI shr 8) and 0xFF) at __PAD_BUF:(__LEN_POS + 2)
	store byte ((__BITLEN_HI shr 0) and 0xFF) at __PAD_BUF:(__LEN_POS + 3)
	store byte ((__BITLEN_LO shr 24) and 0xFF) at __PAD_BUF:(__LEN_POS + 4)
	store byte ((__BITLEN_LO shr 16) and 0xFF) at __PAD_BUF:(__LEN_POS + 5)
	store byte ((__BITLEN_LO shr 8) and 0xFF) at __PAD_BUF:(__LEN_POS + 6)
	store byte ((__BITLEN_LO shr 0) and 0xFF) at __PAD_BUF:(__LEN_POS + 7)

	store dword 0x428a2f98 at __SHA_K:(0 * 4)
	store dword 0x71374491 at __SHA_K:(1 * 4)
	store dword 0xb5c0fbcf at __SHA_K:(2 * 4)
	store dword 0xe9b5dba5 at __SHA_K:(3 * 4)
	store dword 0x3956c25b at __SHA_K:(4 * 4)
	store dword 0x59f111f1 at __SHA_K:(5 * 4)
	store dword 0x923f82a4 at __SHA_K:(6 * 4)
	store dword 0xab1c5ed5 at __SHA_K:(7 * 4)
	store dword 0xd807aa98 at __SHA_K:(8 * 4)
	store dword 0x12835b01 at __SHA_K:(9 * 4)
	store dword 0x243185be at __SHA_K:(10 * 4)
	store dword 0x550c7dc3 at __SHA_K:(11 * 4)
	store dword 0x72be5d74 at __SHA_K:(12 * 4)
	store dword 0x80deb1fe at __SHA_K:(13 * 4)
	store dword 0x9bdc06a7 at __SHA_K:(14 * 4)
	store dword 0xc19bf174 at __SHA_K:(15 * 4)
	store dword 0xe49b69c1 at __SHA_K:(16 * 4)
	store dword 0xefbe4786 at __SHA_K:(17 * 4)
	store dword 0x0fc19dc6 at __SHA_K:(18 * 4)
	store dword 0x240ca1cc at __SHA_K:(19 * 4)
	store dword 0x2de92c6f at __SHA_K:(20 * 4)
	store dword 0x4a7484aa at __SHA_K:(21 * 4)
	store dword 0x5cb0a9dc at __SHA_K:(22 * 4)
	store dword 0x76f988da at __SHA_K:(23 * 4)
	store dword 0x983e5152 at __SHA_K:(24 * 4)
	store dword 0xa831c66d at __SHA_K:(25 * 4)
	store dword 0xb00327c8 at __SHA_K:(26 * 4)
	store dword 0xbf597fc7 at __SHA_K:(27 * 4)
	store dword 0xc6e00bf3 at __SHA_K:(28 * 4)
	store dword 0xd5a79147 at __SHA_K:(29 * 4)
	store dword 0x06ca6351 at __SHA_K:(30 * 4)
	store dword 0x14292967 at __SHA_K:(31 * 4)
	store dword 0x27b70a85 at __SHA_K:(32 * 4)
	store dword 0x2e1b2138 at __SHA_K:(33 * 4)
	store dword 0x4d2c6dfc at __SHA_K:(34 * 4)
	store dword 0x53380d13 at __SHA_K:(35 * 4)
	store dword 0x650a7354 at __SHA_K:(36 * 4)
	store dword 0x766a0abb at __SHA_K:(37 * 4)
	store dword 0x81c2c92e at __SHA_K:(38 * 4)
	store dword 0x92722c85 at __SHA_K:(39 * 4)
	store dword 0xa2bfe8a1 at __SHA_K:(40 * 4)
	store dword 0xa81a664b at __SHA_K:(41 * 4)
	store dword 0xc24b8b70 at __SHA_K:(42 * 4)
	store dword 0xc76c51a3 at __SHA_K:(43 * 4)
	store dword 0xd192e819 at __SHA_K:(44 * 4)
	store dword 0xd6990624 at __SHA_K:(45 * 4)
	store dword 0xf40e3585 at __SHA_K:(46 * 4)
	store dword 0x106aa070 at __SHA_K:(47 * 4)
	store dword 0x19a4c116 at __SHA_K:(48 * 4)
	store dword 0x1e376c08 at __SHA_K:(49 * 4)
	store dword 0x2748774c at __SHA_K:(50 * 4)
	store dword 0x34b0bcb5 at __SHA_K:(51 * 4)
	store dword 0x391c0cb3 at __SHA_K:(52 * 4)
	store dword 0x4ed8aa4a at __SHA_K:(53 * 4)
	store dword 0x5b9cca4f at __SHA_K:(54 * 4)
	store dword 0x682e6ff3 at __SHA_K:(55 * 4)
	store dword 0x748f82ee at __SHA_K:(56 * 4)
	store dword 0x78a5636f at __SHA_K:(57 * 4)
	store dword 0x84c87814 at __SHA_K:(58 * 4)
	store dword 0x8cc70208 at __SHA_K:(59 * 4)
	store dword 0x90befffa at __SHA_K:(60 * 4)
	store dword 0xa4506ceb at __SHA_K:(61 * 4)
	store dword 0xbef9a3f7 at __SHA_K:(62 * 4)
	store dword 0xc67178f2 at __SHA_K:(63 * 4)

	__H0 = 0x6a09e667
	__H1 = 0xbb67ae85
	__H2 = 0x3c6ef372
	__H3 = 0xa54ff53a
	__H4 = 0x510e527f
	__H5 = 0x9b05688c
	__H6 = 0x1f83d9ab
	__H7 = 0x5be0cd19

	repeat __NUM_BLOCKS
		__BLK_BASE = (% - 1) * 64

		repeat 16
			__wi = % - 1

			load __b0 byte from __PAD_BUF:(__BLK_BASE + __wi * 4 + 0)
			load __b1 byte from __PAD_BUF:(__BLK_BASE + __wi * 4 + 1)
			load __b2 byte from __PAD_BUF:(__BLK_BASE + __wi * 4 + 2)
			load __b3 byte from __PAD_BUF:(__BLK_BASE + __wi * 4 + 3)

			__word32 = ((__b0 shl 24) or (__b1 shl 16) or (__b2 shl 8) or (__b3)) and 0xFFFFFFFF
			store dword __word32 at __SHA_W:(__wi * 4)
		end repeat

		repeat 48
			__idxW = (% - 1) + 16

			load __wim15 dword from __SHA_W:((__idxW - 15) * 4)
			load __wim2 dword from __SHA_W:((__idxW - 2) * 4)
			load __wim16 dword from __SHA_W:((__idxW - 16) * 4)
			load __wim7 dword from __SHA_W:((__idxW - 7) * 4)

			__s0 = ((((__wim15 shr 7) or ((__wim15 shl (32 - 7)) and 0xFFFFFFFF))) xor (((__wim15 shr 18) or ((__wim15 shl (32 - 18)) and 0xFFFFFFFF))) xor (__wim15 shr 3)) and 0xFFFFFFFF
			__s1 = ((((__wim2 shr 17) or ((__wim2 shl (32 - 17)) and 0xFFFFFFFF))) xor (((__wim2 shr 19) or ((__wim2 shl (32 - 19)) and 0xFFFFFFFF))) xor (__wim2 shr 10)) and 0xFFFFFFFF


			__newW = (__wim16 + __s0 + __wim7 + __s1) and 0xFFFFFFFF
			store dword __newW at __SHA_W:(__idxW * 4)
		end repeat

		__a = __H0
		__b = __H1
		__c = __H2
		__d = __H3
		__e = __H4
		__f = __H5
		__g = __H6
		__h = __H7

		repeat 64
			__rid = (% - 1)

			load __Wi dword from __SHA_W:(__rid * 4)
			load __Ki dword from __SHA_K:(__rid * 4)

			__S1 = ((((__e shr 6) or ((__e shl (32 - 6)) and 0xFFFFFFFF))) xor (((__e shr 11) or ((__e shl (32 - 11)) and 0xFFFFFFFF))) xor (((__e shr 25) or ((__e shl (32 - 25)) and 0xFFFFFFFF)))) and 0xFFFFFFFF
			__ch = (((__e and __f) xor ((not __e) and __g))) and 0xFFFFFFFF

			__temp1 = (__h + __S1 + __ch + __Ki + __Wi) and 0xFFFFFFFF

			__S0 = ((((__a shr 2) or ((__a shl (32 - 2)) and 0xFFFFFFFF))) xor (((__a shr 13) or ((__a shl (32 - 13)) and 0xFFFFFFFF))) xor (((__a shr 22) or ((__a shl (32 - 22)) and 0xFFFFFFFF)))) and 0xFFFFFFFF ; if you somehow scrolled all the way here, looking back, should have made a ror and rol calm instruction
			__maj = (((__a and __b) xor (__a and __c) xor (__b and __c))) and 0xFFFFFFFF
			__temp2 = (__S0 + __maj) and 0xFFFFFFFF

			__new_h = __g
			__new_g = __f
			__new_f = __e
			__new_e = (__d + __temp1) and 0xFFFFFFFF
			__new_d = __c
			__new_c = __b
			__new_b = __a
			__new_a = (__temp1 + __temp2) and 0xFFFFFFFF

			__a = __new_a
			__b = __new_b
			__c = __new_c
			__d = __new_d
			__e = __new_e
			__f = __new_f
			__g = __new_g
			__h = __new_h
		end repeat

		__tH0 = (__H0 + __a) and 0xFFFFFFFF
		__tH1 = (__H1 + __b) and 0xFFFFFFFF
		__tH2 = (__H2 + __c) and 0xFFFFFFFF
		__tH3 = (__H3 + __d) and 0xFFFFFFFF
		__tH4 = (__H4 + __e) and 0xFFFFFFFF
		__tH5 = (__H5 + __f) and 0xFFFFFFFF
		__tH6 = (__H6 + __g) and 0xFFFFFFFF
		__tH7 = (__H7 + __h) and 0xFFFFFFFF

		__H0 = __tH0
		__H1 = __tH1
		__H2 = __tH2
		__H3 = __tH3
		__H4 = __tH4
		__H5 = __tH5
		__H6 = __tH6
		__H7 = __tH7
	end repeat

	__DIG_OFF = __SIG_START

	store byte ((__H0 shr 24) and 0xFF) at (__DIG_OFF + 0)
	store byte ((__H0 shr 16) and 0xFF) at (__DIG_OFF + 1)
	store byte ((__H0 shr 8) and 0xFF) at (__DIG_OFF + 2)
	store byte ((__H0 shr 0) and 0xFF) at (__DIG_OFF + 3)

	store byte ((__H1 shr 24) and 0xFF) at (__DIG_OFF + 4)
	store byte ((__H1 shr 16) and 0xFF) at (__DIG_OFF + 5)
	store byte ((__H1 shr 8) and 0xFF) at (__DIG_OFF + 6)
	store byte ((__H1 shr 0) and 0xFF) at (__DIG_OFF + 7)

	store byte ((__H2 shr 24) and 0xFF) at (__DIG_OFF + 8)
	store byte ((__H2 shr 16) and 0xFF) at (__DIG_OFF + 9)
	store byte ((__H2 shr 8) and 0xFF) at (__DIG_OFF + 10)
	store byte ((__H2 shr 0) and 0xFF) at (__DIG_OFF + 11)

	store byte ((__H3 shr 24) and 0xFF) at (__DIG_OFF + 12)
	store byte ((__H3 shr 16) and 0xFF) at (__DIG_OFF + 13)
	store byte ((__H3 shr 8) and 0xFF) at (__DIG_OFF + 14)
	store byte ((__H3 shr 0) and 0xFF) at (__DIG_OFF + 15)

	store byte ((__H4 shr 24) and 0xFF) at (__DIG_OFF + 16)
	store byte ((__H4 shr 16) and 0xFF) at (__DIG_OFF + 17)
	store byte ((__H4 shr 8) and 0xFF) at (__DIG_OFF + 18)
	store byte ((__H4 shr 0) and 0xFF) at (__DIG_OFF + 19)

	store byte ((__H5 shr 24) and 0xFF) at (__DIG_OFF + 20)
	store byte ((__H5 shr 16) and 0xFF) at (__DIG_OFF + 21)
	store byte ((__H5 shr 8) and 0xFF) at (__DIG_OFF + 22)
	store byte ((__H5 shr 0) and 0xFF) at (__DIG_OFF + 23)

	store byte ((__H6 shr 24) and 0xFF) at (__DIG_OFF + 24)
	store byte ((__H6 shr 16) and 0xFF) at (__DIG_OFF + 25)
	store byte ((__H6 shr 8) and 0xFF) at (__DIG_OFF + 26)
	store byte ((__H6 shr 0) and 0xFF) at (__DIG_OFF + 27)

	store byte ((__H7 shr 24) and 0xFF) at (__DIG_OFF + 28)
	store byte ((__H7 shr 16) and 0xFF) at (__DIG_OFF + 29)
	store byte ((__H7 shr 8) and 0xFF) at (__DIG_OFF + 30)
	store byte ((__H7 shr 0) and 0xFF) at (__DIG_OFF + 31)

	repeat (LBF_SIG_SIZE - 32)
		store byte 0 at (__DIG_OFF + 32 + (% - 1))
	end repeat
end postpone

macro ? line&
	macro __handle_label name, ln&
		; TODO emit LBF_T_SYMIDX and LBF_T_SYMSTR 
	end macro

	match name: rest, line
		match a b, name
		else
			__handle_label name, line
		end match
	end match

	match name:, line
		match a b, name
		else
			__handle_label name, line
		end match
	end match

	line

	purge __handle_label
end macro

