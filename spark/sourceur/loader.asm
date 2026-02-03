
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

struct lbf_header
	.magic rd 1
	.flags rd 1
	.entry_seg rd 1
	.entry_off rd 1
	.data_seg rd 1
	.stack_size rd 1
	.rva_strings rd 1
	.dir_count rd 1
end struct

struct lbf_dir_entry
	.name_off rd 1
	.rva_dir rd 1
end struct

struct lbf_seg_entry
	.name_off rd 1
	.file_off rd 1
	.file_size rd 1
	.mem_size rd 1
	.type rd 1
	.align rw 1
	.flags rw 1
end struct

struct lbf_rel_entry
	.src_seg rd 1
	.src_off rd 1
	.tgt_seg rd 1
	.type rd 1
end struct

; [in] ESI = file base
; [out] EAX = entry CS
; [out] EBX = gdt base
; [out] ECX = entry EIP
; [out] EDX = stack base
; [out] ESI = gdt limit
; [out] EDI = entry SS
lbf_load:
	push bp
	mov bp, sp

	; stack frame
	; dword(0) [bp - 4] = file base
	; dword(1) [bp - 8] = segment directory linear address
	; dword(2) [bp - 12] = physical base of allocations
	; dword(3) [bp - 16] = segment table pointer
	; dword(4) [bp - 20] = total memory size required
	; dword(5) [bp - 24] = temporary count.
	; dword(6) [bp - 28] = spark segment physical base
	; dword(7) [bp - 32] = spark segment size
	sub sp, 32

	mov dword [bp - 4], esi

	mov dword [bp - 28], 0
	mov dword [bp - 32], 0

	; accumulate total spark segment size.
	lea ebx, [spark_export_table]
	xor ecx, ecx
.spark_calc_loop:
	; check for null terminator.
	mov eax, [ebx]
	test eax, eax
	jz .spark_calc_done

	; align size to 4 bytes.
	mov eax, [ebx + 8]
	add eax, 3
	and eax, 0xfffffffc
	add ecx, eax

	; move to the next entry.
	add ebx, 12
	jmp .spark_calc_loop

.spark_calc_done:
	; nothing to export?
	test ecx, ecx
	jz .spark_load_done

	mov [bp - 32], ecx
	push ecx

	; align to page size.
	mov ebx, ecx
	add ebx, 0xfff
	and ebx, 0xfffff000

	call paslr_find_usable
	test eax, eax
	jz .err_nomem

	; save the physical base of spark segment.
	mov [bp - 28], eax
	
	mov edi, eax
	pop ecx

	mov ebx, spark_export_table
.spark_copy_loop:
	mov eax, [ebx]
	test eax, eax
	jz .spark_load_done

	push ecx edi

	; load payload and length.
	mov esi, [ebx + 4]
	mov ecx, [ebx + 8]
	addr32 data32 rep movsb

	pop edi ecx

	; advance dest pointer by aligned length.
	mov eax, [ebx + 8]
	add eax, 3
	and eax, 0xfffffffc
	add edi, eax

	; next entry.
	add ebx, 12
	jmp .spark_copy_loop

.spark_load_done:
	mov esi, dword [bp - 4]

	; check the lbf magic.
	cmp dword [esi + lbf_header.magic], LBF_MAGIC
	jne .err_magic

	; find the segment directory.
	lea eax, [str_segment_dir]
	call lbf_find_dir

	test eax, eax
	jz .err_no_segs

	; convert rva to pointer and store in the stack frame.
	add eax, dword [bp - 4]
	mov dword [bp - 8], eax

	mov edi, eax

	; read the segment count.
	mov ecx, dword [edi]

	push ecx

	; allocate space for the segment table.
	mov ax, cx
	shl ax, 2
	call arena_alloc16

	; store the segment table pointer in the stack frame.
	mov word [bp - 16], ax
	mov word [bp - 14], 0

	pop ecx

	; pointer to the first entry.
	add edi, 4

	; accumulate required pages in ebx
	xor ebx, ebx
.calc_loop:
	test ecx, ecx
	jz .calc_done

	movzx edx, word [edi + lbf_seg_entry.align]
	test edx, edx
	jnz .align_ok

	; default alignment is 16 bytes.
	mov edx, 16
	mov word [edi + lbf_seg_entry.align], dx
.align_ok:
	; align accumulator to alignment.
	dec edx
	add ebx, edx
	not edx
	and ebx, edx

	; add memory size.
	add ebx, dword [edi + lbf_seg_entry.mem_size]

	; move to the next segment.
	add edi, sizeof.lbf_seg_entry
	dec ecx
	jmp .calc_loop

.calc_done:
	; add stack size to allocation.
	mov esi, dword [bp - 4]
	add ebx, dword [esi + lbf_header.stack_size]

	; align the total to a page.
	add ebx, 0xfff
	and ebx, 0xfffff000
	mov dword [bp - 20], ebx

	; get the memory from paslr.
	call paslr_find_usable
	test eax, eax
	jz .err_nomem

	; save the physical base.
	mov dword [bp - 12], eax

	; get the segment count and pointer.
	mov edi, dword [bp - 8]
	mov ecx, dword [edi]
	add edi, 4

	; load physical base.
	mov esi, eax

	; load segment table pointer.
	mov ebx, dword [bp - 16]
.load_loop:
	test ecx, ecx
	jz .load_finish

	push ecx

	; alignment is already fixed up.
	movzx ecx, word [edi + lbf_seg_entry.align]

	; align the physical address.
	dec ecx
	add esi, ecx
	not ecx
	and esi, ecx

	; store the address into the segment table.
	mov dword [ebx], esi

	; copy segment data.
	push edi

	; load target into EDI.
	mov ecx, [edi + lbf_seg_entry.file_size]
	xchg edi, esi

	; load source into ESI.
	mov esi, dword [esi + lbf_seg_entry.file_off]
	add esi, dword [bp - 4]
	addr32 data32 rep movsb

	; real mode does not have `mov edi, dword [sp]`
	pop edi
	push edi

	; zero out bss if present.
	mov ecx, [edi + lbf_seg_entry.mem_size]
	sub ecx, [edi + lbf_seg_entry.file_size]
	jle .skip_bss

	; load target address at the end of copied data.
	mov edi, dword [edi + lbf_seg_entry.file_size]
	add edi, dword [ebx]
	xor eax, eax
	addr32 data32 rep stosb

.skip_bss:
	pop edi

	; esi is at the end of the segment.
	mov esi, dword [edi + lbf_seg_entry.mem_size]
	add esi, dword [ebx]

	; move to the next segment table.
	add ebx, 4

	; move to the next segment entry.
	add edi, sizeof.lbf_seg_entry

	; restore the loop counter.
	pop ecx
	dec ecx

	jmp .load_loop

.load_finish:
	; find the relocations table.
	mov esi, dword [bp - 4]
	lea eax, [str_relocs_dir]
	call lbf_find_dir

	test eax, eax
	jz .relocs_done

	; convert rva to pointer.
	add eax, dword [bp - 4]
	
	; get the relocation count and pointer to first reloc.
	mov edi, eax
	mov ecx, dword [edi]
	add edi, 4
.reloc_loop:
	test ecx, ecx
	jz .relocs_done

	; only RELOC_SEL16 are supported.
	cmp dword [edi + lbf_rel_entry.type], RELOC_SEL16
	jne .next_reloc

	; convert target segment index to GDT selector.
	mov eax, dword [edi + lbf_rel_entry.tgt_seg]

	; skip null entry.
	inc eax

	; convert to gdt selector.
	shl eax, 3

	; get the physical base of the source segment.
	mov esi, dword [edi + lbf_rel_entry.src_seg]
	shl esi, 2
	add esi, dword [bp - 16]
	mov edx, dword [esi]

	; add the offset to get the patch physical address.
	add edx, dword [edi + lbf_rel_entry.src_off]

	; perform the patch.
	mov word [edx], ax
.next_reloc:
	add edi, sizeof.lbf_rel_entry
	dec ecx
	jmp .reloc_loop

.relocs_done:
	; are there any exports of spark?
	cmp dword [bp - 32], 0
	jz .imports_done

	; find the import directory.
	mov esi, dword [bp - 4]
	lea eax, [str_imports_dir]
	call lbf_find_dir

	; supervisor has no imports.
	test eax, eax
	jz .imports_done

	; convert rva to pointer.
	add eax, esi

	; read module count and prepare pointer to first module.
	mov ecx, [eax]
	add eax, 4
.mod_loop:
	; no more imports?
	test ecx, ecx
	jz .imports_done

	; convert offset to rva to pointer.
	mov ebx, [eax]
	add ebx, [esi + lbf_header.rva_strings]
	add ebx, esi

	; compare the name to `spark`.
	lea edi, [str_spark_mod]
.mod_cmp_loop:
	mov dl, byte [edi]

	; byte mismatch.
	cmp dl, byte [ebx]
	jne .next_mod

	; null terminator reached.
	test dl, dl
	jz .found

	inc edi
	inc ebx

	jmp .mod_cmp_loop

.mod_done:
	pop eax
.next_mod:
	; next module entry.
	add eax, 12
	dec ecx
	jmp .mod_loop

.found:
	push eax

	; get ILT pointer.
	mov esi, [eax + 4]
	add esi, dword [bp - 4]
	
	; get IPT rva.
	mov edi, [eax + 8]
.func_loop:
	mov ebx, [esi]

	; check for ILT null terminator.
	test ebx, ebx
	jz .mod_done

	; convert string offset to rva to pointer.
	mov edx, dword [bp - 4]
	add ebx, [edx + lbf_header.rva_strings]
	add ebx, edx

	; find the symbol in spark export table.
	push ecx esi edi
	call lbf_find_spark_offset
	mov edx, eax
	pop edi esi ecx

	; supervisor requests but spark doesn't export.
	cmp edx, -1
	je .next_func

	push ebx

	; calculate spark selector.
	mov ebx, dword [bp - 8]
	mov ebx, [ebx]
	add ebx, 2
	shl ebx, 3

	push edx

	; convert rva to physical address
	mov eax, edi
	call lbf_rva_to_phys
	mov edx, eax

	pop eax

	; patch far pointer.
	mov [edx], eax
	mov [edx + 4], bx

	pop ebx
.next_func:
	; next ILT entry.
	add esi, 4

	; next IPT entry.
	add edi, 6

	jmp .func_loop

.imports_done:
	; calculate needed memory for the GDT.
	mov edi, dword [bp - 8]
	mov ecx, dword [edi]
	add ecx, 3

	; if spark segment exists, add one more.
	cmp dword [bp - 32], 0
	jz .no_spark_gdt
	inc ecx
.no_spark_gdt:
	push ecx

	; allocate the GDT.
	shl cx, 3
	call arena_alloc16
	movzx edi, ax

	pop ecx

	push edi

	; null descriptor.
	xor eax, eax
	stosd
	stosd
	dec ecx

	; get pointer to the first segment entry.
	mov ebx, dword [bp - 8]
	mov edx, ebx
	add edx, 4

	; get pointer to the segment table.
	mov ebx, dword [bp - 16]

	; store the segment count.
	mov eax, dword [edx - 4]
	mov dword [bp - 24], eax
.gdt_build_loop:
	test ecx, ecx
	jz .gdt_built

	cmp dword [bp - 24], 0
	jz .gdt_stack_seg

	push ebx ecx

	; load physical base.
	mov ebx, dword [ebx]
	
	; load limit.
	mov ecx, dword [edx + lbf_seg_entry.mem_size]
	dec ecx

	; convert LBF type to access byte.
	mov eax, dword [edx + lbf_seg_entry.type]
	call lbf_type_to_access

	call emit_gdt_entry
	
	pop ecx ebx

	; next physical address.
	add ebx, 4

	; next directory entry.
	add edx, sizeof.lbf_seg_entry
	dec dword [bp - 24]
	dec ecx

	jmp .gdt_build_loop

.gdt_stack_seg:
	push ebx ecx

	; load file base to read header fields.
	mov esi, dword [bp - 4]

	; compute stack base.
	mov ebx, dword [bp - 12]
	add ebx, dword [bp - 20]
	sub ebx, dword [esi + lbf_header.stack_size]

	; get the stack limit.
	mov ecx, dword [esi + lbf_header.stack_size]
	dec ecx

	; emit the stack segment.
	mov al, 0x92
	call emit_gdt_entry

	pop ecx ebx
	dec ecx

	; check for spark segment.
	test ecx, ecx
	jz .gdt_built

	push ebx ecx

	; get the spark segment base and limit.
	mov ebx, dword [bp - 28]
	mov ecx, dword [bp - 32]
	dec ecx

	; emit the spark segment.
	mov al, 0x92
	call emit_gdt_entry

	; emit a flat 4GiB segment.
	xor ebx, ebx
	mov ecx, 0xffffffff
	mov al, 0x92
	call emit_gdt_entry

	; find the symbol in spark export table.
	lea ebx, [str_flat_seg_sym]
	call lbf_find_spark_offset
	cmp eax, -1
	je .flat_done

	; convert the spark physical base to a pointer.
	add eax, [bp - 28]

	; calculate the flat selector index.
	mov edx, [bp - 8]
	mov edx, [edx]
	add edx, 2

	cmp dword [bp - 32], 0
	jz .calc_flat_sel
	inc edx
.calc_flat_sel:
	shl edx, 3
	mov [eax], dx

.flat_done:
	pop ecx ebx
.gdt_built:
	; get the segment count, which is the SS index.
	mov edi, dword [bp - 8]
	mov edi, [edi]

	; convert index to selector.
	inc edi
	shl edi, 3

	; place the stack at the top of the allocated memory.
	mov edx, dword [esi + lbf_header.stack_size]

	; calculate entry CS.
	mov eax, [esi + lbf_header.entry_seg]
	inc eax
	shl eax, 3

	; return the GDT base.
	pop ebx

	; load entry EIP
	mov ecx, dword [esi + lbf_header.entry_off]

	; calculate the gdt limit.
	mov esi, edi
	cmp dword [bp - 32], 0
	jz .limit_calc

	add esi, 16
.limit_calc:
	add esi, 7

	call patch_memmap

	mov sp, bp
	pop bp
	ret

.err_magic:
	print 'Invalid supervisor magic!', 10
	jmp panic

.err_no_segs:
	print 'No segments found in supervisor!', 10
	jmp panic

.err_nomem:
	print 'Not enough memory to boot supervisor!', 10
	jmp panic

; [in] EAX = pointer to null terminiated string.
; [in] ESI = file base
; [out] EAX = rva of directory
lbf_find_dir:
	push ebx ecx edx esi edi ebp

	; load the string table rva.
	mov ebp, [esi + lbf_header.rva_strings]

	; load the directory count.
	mov ecx, [esi + lbf_header.dir_count]
	
	; prepare a directory table iterator.
	mov edi, esi
	add edi, sizeof.lbf_header
.loop:
	test ecx, ecx
	jz .not_found

	; load name pointer.
	mov ebx, [edi]
	add ebx, ebp
	add ebx, esi

	push eax
	; compare ebx and eax unitl null terminator.
.cmp_loop:
	mov dl, byte [ebx]
	mov dh, byte [eax]

	; byte in name does not match.
	cmp dl, dh
	jne .not_match

	; we found a match.
	test dl, dl
	jz .match

	inc eax
	inc ebx

	jmp .cmp_loop

.not_match:
	pop eax

	; move to the next directory
	add edi, 8
	dec ecx

	jmp .loop

.match:
	pop eax
	mov eax, [edi + 4]
	pop ebp edi esi edx ecx ebx
	ret

.not_found:
	xor eax, eax
	pop ebp edi esi edx ecx ebx
	ret

; [in] EDI = destination pointer
; [in] EBX = base address
; [in] ECX = limit
; [in] AL = access byte
emit_gdt_entry:
	push ebx ecx edx

	xor dh, dh

	; for limit > 1MB use 4KiB pages.
	cmp ecx, 0xFFFFF
	jbe .gran_byte

	shr ecx, 12

	; G=1 (4KB), D/B=1 (32-bit)
	mov dh, 0xC0
	jmp .write

.gran_byte:
	; G=0 (Byte), D/B=1 (32-bit)
	mov dh, 0x40
.write:
	; store limit low.
	mov word [edi], cx
	
	; store base low.
	mov word [edi + 2], bx

	; store base middle.
	shr ebx, 16
	mov byte [edi + 4], bl

	; store access byte.
	mov byte [edi + 5], al

	; store limit high.
	and ecx, 0xf0000
	shr ecx, 16
	or cl, dh
	mov byte [edi + 6], cl

	; store base high.
	mov byte [edi + 7], bh

	add edi, 8

	pop edx ecx ebx
	ret

; [in] EAX = lbf type
; [out] AL = access byte
lbf_type_to_access:
	cmp eax, ST_CODE_RX
	je .code

	cmp eax, ST_DATA_RO
	je .data

	cmp eax, ST_DATA_RW
	je .data_rw

	cmp eax, OTHER_RW
	je .data_rw

	mov al, 0x90
	ret

.code:
	mov al, 0x99
	ret

.data:
	mov al, 0x90
	ret

.data_rw:
	mov al, 0x92
	ret

; [in] EBX = pointer string to find
; [out] EAX = offset in spark segment
lbf_find_spark_offset:
	push esi edi ecx

	mov esi, spark_export_table
	xor edi, edi
.scan:
	; load the pointer to the exported symbol name from the table.
	mov eax, [esi]
	test eax, eax
	jz .not_found

	push esi edi

	; load target string and string tabele pointers.
	mov esi, eax
	mov edi, ebx
.cmp_loop:
	mov al, [esi]
	mov ah, [edi]

	cmp al, ah
	jne .no_match

	test al, al
	jz .match

	inc esi
	inc edi
	jmp .cmp_loop

.no_match:
	pop edi esi

	; align payload length to 4 bytes.
	mov ecx, [esi + 8]
	add ecx, 3
	and ecx, 0xfffffffc
	add edi, ecx

	; next entry.
	add esi, 12
	jmp .scan

.match:
	pop edi esi
	mov eax, edi

	pop ecx edi esi
	ret

.not_found:
	mov eax, -1

	pop ecx edi esi
	ret

; [in] EAX = rva
; [in] BP = stack frame
; [out] EAX = physical address
lbf_rva_to_phys:
	push ebx ecx edx esi edi

	; load the segment directory pointer and segment count.
	mov esi, dword [bp - 8]
	mov ecx, [esi]

	; load the first entry of segments and physical address table.
	add esi, 4
	mov ebx, dword [bp - 16]
.seg_scan:
	test ecx, ecx
	jz .fail

	; rva is before this segment?
	mov edx, [esi + lbf_seg_entry.file_off]
	cmp eax, edx
	jb .next

	; rva is after this segment?
	mov edi, edx
	add edi, [esi + lbf_seg_entry.file_size]
	cmp eax, edi
	jae .next

	; match found, convert rva to pointer.
	sub eax, edx
	add eax, [ebx]
	jmp .done

.next:
	; move to the next segment directory entry.
	add esi, sizeof.lbf_seg_entry

	; move to the next physical address entry.
	add ebx, 4

	dec ecx
	jmp .seg_scan

.fail:
	xor eax, eax
.done:
	pop edi esi edx ecx ebx
	ret

ldr_load_loom:
	mov esi, supervisor_bounce_buffer_flat
	call lbf_load

	cli

	; construct a transition gdt on the stack.
	push dword 0x00cf9200
	push dword 0x0000ffff

	push dword 0x00cf9a00
	push dword 0x0000ffff

	push dword 0
	push dword 0

	; calculate the linear address of the gdt on the stack.
	push eax

	xor eax, eax
	mov ax, ss
	shl eax, 4

	movzx ebp, sp
	add ebp, 4
	add ebp, eax

	pop eax

	; construct a gdtr.
	push ebp
	push word 23

	; lgdt the gdtr.
	lgdt [ss:esp]

	; enable protected mode.
	mov ebp, cr0
	or ebp, 1
	mov cr0, ebp

	jmp far 0x08:.pmode_entry

use32
.pmode_entry:
	mov bp, 0x10
	mov ds, bp
	mov ss, bp

	; load a linear esp.
	mov esp, stack_top_flat

	; push the new gdtr onto the stack.
	sub esp, 6
	mov [esp], si
	mov [esp + 2], ebx

	; load the new gdt.
	lgdt [esp]

	; get the entry data segment.
	mov esi, supervisor_bounce_buffer_flat
	mov esi, [esi + lbf_header.data_seg]
	inc esi
	shl esi, 3

	mov ds, esi
	mov ss, edi

	; switch the to supervisor stack.
	mov esp, edx

	; call entry_CS:entry_EIP.
	push eax
	push ecx
	retf

use16
str_segment_dir: db 'SEGMENT', 0
str_relocs_dir: db 'RELOCS', 0
str_imports_dir: db 'IMPORT', 0
str_spark_mod: db 'spark', 0
