
include 'memmap.asm'

MM_PAGE_SIZE = 4096
MM_STRUCT_ALIGN = 4096

; support page sized orders up to a reasonable 1MiB.
; 4KiB
; 8KiB
; 16KiB
; 32KiB
; 64KiB
; 128KiB
; 256KiB
; 512KiB
; 1MiB
MM_MAX_ORDER = 8

; internal structure for a free block header, stored intrusively.
struct MmFreeNode
	prev dd ?
	next dd ?
end struct

struct MmPfaState

if build.debug
	total_mem dd ?
	used_mem dd ?
end if

	; array of pointers to MmFreeNodes.
	free_buckets rd MM_MAX_ORDER + 1
end struct

macro mm$_SET_FLAT sreg?*
	; load the flat segment into es.
	push eax

	mov ax, [loom$flat_segment]
	mov sreg, ax

	pop eax
end macro

segment 'TEXT', ST_CODE_RX

; procedure mm$init();
mm$init:
	push ebx esi edi es fs

	push ds
	pop es

if build.debug
	mov dword [mm_pfa_state.total_mem], 0
	mov dword [mm_pfa_state.used_mem], 0
end if

	; reset the freelist.
	lea edi, [mm_pfa_state.free_buckets]
	mov ecx, MM_MAX_ORDER + 1
	xor eax, eax
	rep stosd

	mm$_SET_FLAT es

	; load a pointer into the memmap entries and the count.
	lfs esi, [loom$memory_map]
	mov ecx, [fs:esi]
	add esi, 4
.loop_map:
	test ecx, ecx
	jz .done

	cmp dword [fs:esi + SparkMemmapEntry.type], MEMMAP_TYPE_USABLE
	jne .next_entry

	; load the region information.
	mov eax, dword [fs:esi + SparkMemmapEntry.base]
	mov edx, dword [fs:esi + SparkMemmapEntry.length]

	; register this region with the allocator.
	push ecx esi
	call mm$_add_region
	pop esi ecx
.next_entry:
	add esi, sizeof.SparkMemmapEntry
	dec ecx
	jmp .loop_map

.done:
	pop fs es edi esi ebx
	ret

; function mm$alloc_pages(order: Cardinal): Pointer;
mm$alloc_pages:
	push ebx esi edi

	cmp eax, MM_MAX_ORDER
	ja .oom

	; stash a copy of the requested order and current search order.
	mov ebx, eax
	mov ecx, eax
.find_block:
	cmp ecx, MM_MAX_ORDER
	jae .oom

	; check if buckets[ecx] has a block.
	mov esi, [mm_pfa_state.free_buckets + ecx * dword]
	test esi, esi
	jnz .found

	inc ecx
	jmp .find_block

.found:
	call mm$_list_pop_head
	; if current search order is higher than the requested order,
	; we must repeatedly split the block.
.split_loop:
	cmp ecx, ebx
	je .success

	; lower the current search order.
	dec ecx

	; keep the address of the left buddy we keep holding in ESI.
	mov edi, 1

	; convert order to bit shift.
	push ecx
	add ecx, 12
	shl edi, cl
	pop ecx

	; calculate the address of the right buddy.
	add edi, esi

	; push the right buddy back onto the freelist at the new split order.
	push eax edx
	mov eax, edi
	mov edx, ecx
	call mm$_list_push
	pop edx eax

	jmp .split_loop

.success:
	mov eax, esi

if build.debug
	; re-calculate the size of the allocated region.
	mov edi, 1

	push ecx
	mov ecx, ebx
	add ecx, 12
	shl edi, cl
	pop ecx

	add [mm_pfa_state.used_mem], edi
end if

	clc
	pop edi esi ebx
	ret

.oom:
	stc
	pop edi esi ebx
	ret

; procedure mm$free_pages(ptr: Cardinal, order: Cardinal);
mm$free_pages:
	push ebx esi edi es

	mm$_SET_FLAT es

if build.debug
	; update the status to free the memory.
	mov edi, 1

	mov ecx, edx
	add ecx, 12
	shl edi, cl

	sub [mm_pfa_state.used_mem], edi
end if

.coalesce_loop:
	cmp edx, MM_MAX_ORDER
	jae .insert_block

	; calculate the shift index from order.
	mov ecx, edx
	add ecx, 12
	mov ebx, 1
	shl ebx, cl

	push eax

	; calculate the buddy address.
	xor eax, ebx

	; attempt to find and remove the buddy from the freelist.
	call mm$_remove_specific_free_block
	pop eax
	jnc .insert_block

	; buddy found and removed, merge.
	; since buddies are naturally aligned, the lower address is `ptr & ~size`
	not ebx
	and eax, ebx

	; increase order and try again.
	inc edx
	jmp .coalesce_loop

.insert_block:
	; add the region back onto the freelist.
	call mm$_list_push

	pop es edi esi ebx
	ret

; procedure mm$_add_region(base: Cardinal, size: Cardinal);
mm$_add_region:
	push ebx esi edi

	; set up counter.
	mov esi, eax
	mov edi, edx
.loop:
	test edi, edi
	jz .done

	; is there less than a page left?
	cmp edi, MM_PAGE_SIZE
	jb .done

	; determinte the alignment of the base.
	; we can only fit a block of order N if base is aligned to 2^(N+12)
	bsf eax, esi
	jz .max_align

	; convert bit position to order.
	sub eax, 12
	jmp .got_align

.max_align:
	mov eax, MM_MAX_ORDER
.got_align:
	mov ebx, eax

	; determinte the maximum order that fits into the size.
	bsr eax, edi
	sub eax, 12
	mov ecx, eax

	; current order is the min(alignment order, size order, MM_MAX_ORDER).
	cmp ebx, ecx
	ja .keep_ecx
	mov ecx, ebx
.keep_ecx:
	cmp ecx, MM_MAX_ORDER
	ja .cap_order
	jmp .order_ok

.cap_order:
	mov ecx, MM_MAX_ORDER
.order_ok:
	push edx

	; add a block of a given order to the list.
	mov eax, esi
	mov edx, ecx
	call mm$_list_push

if build.debug
	push ecx
	mov eax, 1
	add ecx, 12
	shl eax, cl

	add [mm_pfa_state.total_mem], eax
	pop ecx
end if
	pop edx

	; recalculate the size of the block.
	push ecx
	mov eax, 1
	add ecx, 12
	shl eax, cl
	pop ecx

	; advance to the next blocks.
	add esi, eax
	sub edi, eax
	jmp .loop

.done:
	pop edi esi ebx
	ret

; procedure mm$_list_push(ptr: Cardinal, order: Cardinal);
mm$_list_push:
	push ebx es

	mm$_SET_FLAT es

	; build a new linked list entry at the start of the region.
	mov ebx, [mm_pfa_state.free_buckets + edx * dword]
	mov dword [es:eax + MmFreeNode.prev], 0
	mov dword [es:eax + MmFreeNode.next], ebx

	; if the old head exists, update its prev pointer.
	test ebx, ebx
	jz .no_old_head

	mov [es:ebx + MmFreeNode.prev], eax
.no_old_head:
	; write back the new pointer to the head.
	mov [mm_pfa_state.free_buckets + edx * dword], eax

	pop es ebx
	ret

; function mm$_list_pop_head(order: Cardinal): Cardinal;
mm$_list_pop_head:
	push es

	mm$_SET_FLAT es

	; get the old head.
	mov esi, [mm_pfa_state.free_buckets + ecx * dword]

	; get the next node in the list.
	mov eax, [es:esi + MmFreeNode.next]

	; write back the new node.
	mov [mm_pfa_state.free_buckets + ecx * dword], eax

	; if new head exists, clear it's prev pointer.
	test eax, eax
	jz .list_empty
	mov dword [es:eax + MmFreeNode.prev], 0
.list_empty:
	; clear the popped node's pointers for sanity.
	mov dword [es:esi + MmFreeNode.next], 0
	mov dword [es:esi + MmFreeNode.prev], 0

	pop es
	ret

; procedure mm$_list_pop_head(address_of_block: Cardinal, order: Cardinal);
mm$_remove_specific_free_block:
	push ebx esi edi

	; load the head of the list for this order.
	mov edi, [mm_pfa_state.free_buckets + edx * dword]
.scan:
	test edi, edi
	jz .not_found

	cmp edi, eax
	je .found

	; next node.
	mov edi, [es:edi + MmFreeNode.next]
	jmp .scan

.found:
	; unlink the node.
	mov esi, [es:edi + MmFreeNode.prev]
	mov ebx, [es:edi + MmFreeNode.next]

	; if there is no prev we are at head.
	test esi, esi
	jz .is_head

	; point the prev's next pointer to pop'd next.
	mov [es:esi + MmFreeNode.next], ebx
	jmp .fix_next

.is_head:
	mov [mm_pfa_state.free_buckets + edx * dword], ebx
.fix_next:
	test ebx, ebx
	jz .done

	; point the next's prev pointer to pop'd prev.
	mov [es:ebx + MmFreeNode.prev], esi
.done:
	; clear the removed node's pointers for sanity.
	mov dword [es:edi + MmFreeNode.prev], 0
	mov dword [es:edi + MmFreeNode.next], 0

	stc
	pop edi esi ebx
	ret

.not_found:
	clc
	pop edi esi ebx
	ret

segment 'DATA', ST_DATA_RW
mm_pfa_state MmPfaState
