use32

LBF_MAGIC = 0x1a4c4246
PAGE_SIZE = 4096

LBF_T_SECTIONS = 2

LBFHeader.magic = 0
LBFHeader.version = 4
LBFHeader.abi_major = 8
LBFHeader.abi_minor = 10
LBFHeader.kind = 12
LBFHeader.machine = 14
LBFHeader.flags = 16
LBFHeader.entry_sel = 20
LBFHeader.data_sel = 22
LBFHeader.entry_off = 24
LBFHeader.n_tables = 28
LBFHeader.dir_off = 32
sizeof.LBFHeader = 36

LBFDirEnt.type = 0
LBFDirEnt.reserved = 2
LBFDirEnt.offset = 4
LBFDirEnt.size = 8
LBFDirEnt.count = 12
sizeof.LBFDirEnt = 16

LBFSection.name = 0
LBFSection.seg_index = 4
LBFSection.sect_kind = 6
LBFSection.file_off = 8
LBFSection.file_sz = 12
LBFSection.mem_off = 16
LBFSection.mem_sz = 20
LBFSection.align = 24
LBFSection.flags = 28
sizeof.LBFSection = 32

lbf_size_from_ptr.errcode.invalid_magic = 1
lbf_size_from_ptr.errcode.section_table_not_found = 2


; In: ESI = pointer to file base
; Out: CF=1 -> EAX = kernel physical memory size
;      CF=0 -> EAX = err code
lbf_size_from_ptr:
	push esi edi ebx ecx edx

	mov eax, dword [esi]
	cmp eax, LBF_MAGIC
	jne .invalid_magic

	mov edx, dword [esi + LBFHeader.n_tables]
	mov edi, esi
	add edi, dword [esi + LBFHeader.dir_off]

.iterate_directories:
	movzx eax, word [edi]
	cmp eax, LBF_T_SECTIONS
	je .found_section_table

	dec edx
	jz .section_table_not_found

	add edi, sizeof.LBFDirEnt
	jmp .iterate_directories

.found_section_table:
	xor eax, eax
	mov ecx, dword [edi + LBFDirEnt.count]
	add esi, dword [edi + LBFDirEnt.offset]
.iterate_sections:
	add eax, dword [esi + LBFSection.mem_sz]

	add esi, sizeof.LBFSection
	dec ecx
	jz .done

	jmp .iterate_sections

.done:
	pop edx ecx ebx edi esi
	clc
	ret

.section_table_not_found:
	mov eax, lbf_size_from_ptr.errcode.section_table_not_found
.invalid_magic:
	mov eax, lbf_size_from_ptr.errcode.invalid_magic
.fail:
	pop edx ecx ebx edi esi
	stc
	ret



lbf_size_from_ptr_error:
	cmp eax, lbf_size_from_ptr.errcode.section_table_not_found
	je .section_table_not_found

	cmp eax, lbf_size_from_ptr.errcode.invalid_magic
	je .invalid_magic

	jmp .unkown

.unkown:
	panic 'Unknown error!'

.section_table_not_found:
	panic 'Section table not found!'

.invalid_magic:
	panic 'Invalid LBF magic!'
