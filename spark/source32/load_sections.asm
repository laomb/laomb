

; In: EDI = pointer to kernel load base
load_sections:
	pushad

	mov ebx, edi
	mov esi, kernel_bounce_buffer_flat

	mov eax, [esi + LBFHeader.magic]
	cmp eax, LBF_MAGIC
	jne .bad_magic

	mov edx, [esi + LBFHeader.n_tables]
	mov edi, esi
	add edi, [esi + LBFHeader.dir_off]

.find_dir:
	movzx eax, word [edi + LBFDirEnt.type]
	cmp eax, LBF_T_SECTIONS
	je .have_sections
	dec edx
	jz .no_sections
	add edi, sizeof.LBFDirEnt
	jmp .find_dir

.have_sections:
	mov ecx, [edi + LBFDirEnt.count]
	mov edx, [edi + LBFDirEnt.offset]
	add edx, esi
	mov edi, edx

	cld

.sect_loop:
	test ecx, ecx
	jz .done

	mov eax, [edi + LBFSection.mem_off]
	lea edx, [ebx + eax]

	mov eax, [edi + LBFSection.mem_sz]
	mov ebp, eax
	add eax, edx
	cmp eax, [best_region_end]
	ja .overflow

	mov eax, [edi + LBFSection.align]
	test eax, eax
	jz .align_ok
	dec eax
	test edx, eax
	jz .align_ok

	panic 'LBF section alignment not satisfied'

.align_ok:
	mov esi, kernel_bounce_buffer_flat
	add esi, [edi + LBFSection.file_off]

	mov eax, [edi + LBFSection.file_sz]
	cmp ebp, eax
	jb .bad_sizes

	push edi
	mov edi, edx
	push eax

	mov ecx, eax
	shr ecx, 2
	rep movsd
	pop eax
	mov ecx, eax
	and ecx, 3
	rep movsb

	mov ecx, ebp
	sub ecx, eax
	jz .after_zero
	xor eax, eax
	mov edx, ecx
	shr ecx, 2
	rep stosd
	mov ecx, edx
	and ecx, 3
	rep stosb

.after_zero:
	pop edi
	add edi, sizeof.LBFSection
	dec ecx
	jnz .sect_loop

.done:
	popad
	clc
	ret

.no_sections:
	panic 'Section table not found!'
.bad_magic:
	panic 'Invalid LBF magic!'
.bad_sizes:
	panic 'LBF section mem_sz < file_sz!'
.overflow:
	panic 'LBF section exceeds reserved region!'
