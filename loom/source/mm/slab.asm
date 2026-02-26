
MM_SLUB_MIN_SIZE = 8
MM_SLUB_MAX_SIZE = 512

MM_SLAB_ORDER = 0
MM_SLAB_FREELIST_END = 0xffff

struct MmSlubCache ; todo constructor, destructure and custom size'd caches.
	obj_size dd ? ; size of each object in bytes
	obj_count dd ? ; objects per slab
	obj_start dd ? ; byte offset of first object within a slab page

	full_head dd ? ; ptr to first fully-used MmSlabHeader, or null
	partial_head dd ? ; ptr to first partial MmSlabHeader, or null
	empty_head dd ? ; ptr to first empty MmSlabHeader, or null
end struct

; intrusively stored header.
struct MmSlabHeader
	cache dd ? ; pointer to owning MmSlubCache
	free_head dw ? ; index of first free slot
	free_count dw ? ; number of free slots remaining

	prev dd ?
	next dd ?
end struct

macro mm$_SLAB_OF reg?*
	and reg, 0xfffff000
end macro

macro mm$_CREATE_CACHE size
	local _start, _count

	_start = (sizeof.MmSlabHeader + (size - 1)) and not (size - 1)
	_count = (4096 - _start) / size

	dd size
	dd _count
	dd _start
	dd 0
	dd 0
	dd 0
end macro

segment 'TEXT', ST_CODE_XO

; function mm$slub_alloc(cache_ptr: Cardinal): ^T, CF;
mm$slub_alloc:
	push ebx esi edi ds es

	mov bx, rel 'DATA'
	mov ds, bx

	mm$SET_FLAT es

	; save the cache pointer.
	mov esi, eax

	; try partial list first.
	mov edi, dword [ds:esi + MmSlubCache.partial_head]

	test edi, edi
	jnz .have_slab

	; fallback to empty list.
	mov edi, dword [ds:esi + MmSlubCache.empty_head]
	test edi, edi
	jnz .from_empty

	; no slabs available at all, allocate a new one.
	mov eax, esi
	call mm$_slub_new_slab
	jc .oom

	; hijack empty list path.
	mov edi, dword [ds:esi + MmSlubCache.empty_head]
.from_empty:
	; move slab from empty to partial.
	lea edx, [ds:esi + MmSlubCache.empty_head]
	mov eax, edi
	call mm$_slub_unlink

	lea edx, [ds:esi + MmSlubCache.partial_head]
	mov eax, edi
	call mm$_slub_link
.have_slab:
	; pop the free slot index from the slab's freelist.
	movzx eax, word [es:edi + MmSlabHeader.free_head]
	cmp eax, MM_SLAB_FREELIST_END
	je .corrupt

	; compute slot address.
	mov ebx, eax
	mov ecx, dword [ds:esi + MmSlubCache.obj_size]
	mov edx, dword [ds:esi + MmSlubCache.obj_start]
	imul ebx, ecx
	lea eax, [edi + edx]
	add eax, ebx

	; read next free index from the slot itself before we hand it out.
	movzx ecx, word [es:eax]
	mov word [es:edi + MmSlabHeader.free_head], cx

	; decrement free_count.
	movzx ecx, word [es:edi + MmSlabHeader.free_count]
	dec ecx
	mov word [es:edi + MmSlabHeader.free_count], cx
	
	; no more space?
	test ecx, ecx
	jnz .done_alloc

	; move slab from partial to full list.
	lea edx, [ds:esi + MmSlubCache.partial_head]

	push eax
	mov eax, edi
	call mm$_slub_unlink
	lea edx, [ds:esi + MmSlubCache.full_head]
	call mm$_slub_link
	pop eax

.done_alloc:
	clc
	pop es ds edi esi ebx
	ret

.oom:
.corrupt:
	stc
	pop es ds edi esi ebx
	ret

; procedure mm$slub_free(ptr: Cardinal);
mm$slub_free:
	push ebx esi edi ds es

	mov bx, rel 'DATA'
	mov ds, bx

	mm$SET_FLAT es

	; find slab header.
	mov edi, eax
	mm$_SLAB_OF edi

	; recover the cache ptr.
	mov esi, dword [es:edi + MmSlabHeader.cache]

	; compute slot index.
	mov ebx, eax
	sub ebx, edi
	sub ebx, dword [ds:esi + MmSlubCache.obj_start]
	xor edx, edx
	mov ecx, dword [ds:esi + MmSlubCache.obj_size]

	push eax
	mov eax, ebx
	div ecx
	mov ebx, eax
	pop eax

	; write old free_head into the slot as the next pointer.
	movzx ecx, word [es:edi + MmSlabHeader.free_head]
	mov word [es:eax], cx

	; update slab header.
	mov word [es:edi + MmSlabHeader.free_head], bx
	movzx ecx, word [es:edi + MmSlabHeader.free_count]
	inc ecx
	mov word [es:edi + MmSlabHeader.free_count], cx

	; was the slab full before this free?
	cmp ecx, 1
	jne .check_empty

	; move from full to partial.
	lea edx, [ds:esi + MmSlubCache.full_head]

	push eax
	mov eax, edi
	call mm$_slub_unlink
	lea edx, [ds:esi + MmSlubCache.partial_head]
	call mm$_slub_link
	pop eax

	jmp .done_free

.check_empty:
	; is the slab completely empty now?
	mov ecx, dword [ds:esi + MmSlubCache.obj_count]
	movzx ebx, word [es:edi + MmSlabHeader.free_count]
	cmp ebx, ecx
	jne .done_free

	; move from partial to empty.
	lea edx, [ds:esi + MmSlubCache.partial_head]

	push eax
	mov eax, edi
	call mm$_slub_unlink
	lea edx, [ds:esi + MmSlubCache.empty_head]
	call mm$_slub_link
	pop eax

.done_free:
	pop es ds edi esi ebx
	ret

; function mm$_slub_new_slab(cache_ptr: Cardinal): ^MmSlabHeader, CF;
mm$_slub_new_slab:
	push ebx esi edi ds es

	mov bx, rel 'DATA'
	mov ds, bx

	; save the cache pointer.
	mov esi, eax

	; allocate one page from the PFA.
	mov eax, MM_SLAB_ORDER
	call mm$alloc_pages
	jc .oom

	mm$SET_FLAT es

	; initialize the slab header.
	mov dword [es:eax + MmSlabHeader.cache], esi
	mov dword [es:eax + MmSlabHeader.prev], 0
	mov dword [es:eax + MmSlabHeader.next], 0

	; build the intrusive freelist of slots.
	mov ecx, dword [ds:esi + MmSlubCache.obj_count]
	mov word [es:eax + MmSlabHeader.free_count], cx
	mov word  [es:eax + MmSlabHeader.free_head],  0

	; walk slots and chain them.
	mov edx, dword [ds:esi + MmSlubCache.obj_start]
	mov ecx, dword [ds:esi + MmSlubCache.obj_count]
	mov ebx, dword [ds:esi + MmSlubCache.obj_size]

	; save slab base.
	push eax
	add eax, edx

	mov edi, 0
.chain:
	cmp edi, ecx
	jae .chain_done

	; write next-slot index into the slot's first word.
	mov edx, edi
	inc edx
	cmp edx, ecx
	jb .not_last

	mov edx, MM_SLAB_FREELIST_END
.not_last:
	mov word [es:eax], dx

	; move to the next slot.
	add eax, ebx
	inc edi
	jmp .chain

.chain_done:
	pop eax

	; prepend to cache's empty list.
	push edx

	mov edx, dword [ds:esi + MmSlubCache.empty_head]
	mov dword [es:eax + MmSlabHeader.next], edx

	mov dword [es:eax + MmSlabHeader.prev], 0

	test edx, edx
	jz .no_old_empty

	mov dword [es:edx + MmSlabHeader.prev], eax
.no_old_empty:
	mov dword [ds:esi + MmSlubCache.empty_head], eax

	pop edx

	clc
	pop es ds edi esi ebx
	ret

.oom:
	stc
	pop es ds edi esi ebx
	ret

; procedure mm$_slub_unlink(slab: Cardinal, list_head_ptr: Cardinal);
mm$_slub_unlink:
	push ebx es

	mm$SET_FLAT es

	mov ebx, dword [es:eax + MmSlabHeader.prev]
	mov ecx, dword [es:eax + MmSlabHeader.next]

	; is there no prev?
	test ebx, ebx
	jz .is_head

	mov dword [es:ebx + MmSlabHeader.next], ecx
	jmp .fix_next

.is_head:
	mov dword [edx], ecx
.fix_next:
	; is there no next?
	test ecx, ecx
	jz .done

	mov dword [es:ecx + MmSlabHeader.prev], ebx
.done:
	; zero out the stale links.
	mov dword [es:eax + MmSlabHeader.prev], 0
	mov dword [es:eax + MmSlabHeader.next], 0

	pop es ebx
	ret

; procedure mm$_slub_link(slab: Cardinal, list_head_ptr: Cardinal);
mm$_slub_link:
	push ebx es

	mm$SET_FLAT es

	mov ebx, dword [edx]

	mov dword [es:eax + MmSlabHeader.prev], 0
	mov dword [es:eax + MmSlabHeader.next], ebx

	; was there an old head?
	test ebx, ebx
	jz .no_old

	mov dword [es:ebx + MmSlabHeader.prev], eax
.no_old:
	mov dword [edx], eax

	pop es ebx
	ret

segment 'DATA', ST_DATA_RW

mm_slub_caches:
	iterate <sz>, 8, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512
		mm$_CREATE_CACHE sz
	end iterate

MM_SLUB_CLASS_COUNT = ($ - mm_slub_caches) / sizeof.MmSlubCache
