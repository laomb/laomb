
struct MmLargeAllocHeader
	magic dd ?
	self dd ?
	order dd ?
end struct

MM_LARGE_ALLOC_MAGIC = 0xDEADC0DE

segment 'TEXT', ST_CODE_XO

; function mm$alloc(size: Cardinal): ^Void, CF;
mm$alloc:
	; check for max size
	cmp eax, MM_SLUB_MAX_SIZE
	ja .too_large

	; find the correct cache
	call mm$_get_cache_by_size
	call mm$slub_alloc

	ret

.too_large:
	add eax, sizeof.MmLargeAllocHeader

	; find the smallest order more than ceil(log2(size))
	mov ecx, eax
	dec ecx
	bsr ecx, ecx
	sub ecx, 12

	; clamp to one page.
	jns .order_ok_large
	xor ecx, ecx
.order_ok_large:
	cmp ecx, MM_MAX_ORDER
	jbe .order_in_range

.pfa_oom:
	stc
	ret
.order_in_range:
	; allocate pages and keep the order.
	push ecx
	mov eax, ecx
	call mm$alloc_pages
	pop ecx

	jc .pfa_oom

	; write the large header at the start of the allocations.
	push es
	mm$SET_FLAT es
	mov dword [es:eax + MmLargeAllocHeader.magic], MM_LARGE_ALLOC_MAGIC
	mov dword [es:eax + MmLargeAllocHeader.self], eax
	mov dword [es:eax + MmLargeAllocHeader.order], ecx
	pop es

	; return a pointer to the start of the data region.
	add eax, sizeof.MmLargeAllocHeader
	clc
	ret

; function mm$free(ptr: Cardinal);
mm$free:
	push es
	mm$SET_FLAT es

	; peak if there is a large alloc heeder.
	mov edx, eax
	sub edx, sizeof.MmLargeAllocHeader
	cmp dword [es:edx + MmLargeAllocHeader.magic], MM_LARGE_ALLOC_MAGIC
	jne .slub_free

	; verify the self pointer.
	cmp dword [es:edx + MmLargeAllocHeader.self], edx
    jne .slub_free

	; recover the order to free the page.
	mov eax, edx
	mov edx, dword [es:eax + MmLargeAllocHeader.order]

	; zero out the magic.
	mov dword [es:eax + MmLargeAllocHeader.magic], 0

	pop es

	call mm$free_pages
	ret

.slub_free:
	pop es
	jmp mm$slub_free

; function mm$_get_cache_by_size(size: Cardinal): ^MmSlubCache;
mm$_get_cache_by_size:
	cmp eax, 64
	jbe .le64

	cmp eax, 192
	jbe .le192

	cmp eax, 256
	jbe .class9

	cmp eax, 384
	jbe .class10

	cmp eax, 512
	jbe .class11

	xor eax, eax
	ret

.le192:
	cmp eax, 96
	jbe .class6

	cmp eax, 128
	jbe .class7

	mov ecx, 8
	jmp .ret_index

.le64:
	cmp eax, 24
	jbe .le24

	cmp eax, 32
	jbe .class3

	cmp eax, 48
	jbe .class4

	mov ecx, 5
	jmp .ret_index

.le24:
	cmp eax, 8
	jbe .class0

	cmp eax, 16
	jbe .class1

	mov ecx, 2
	jmp .ret_index

.class0:
	mov ecx, 0
	jmp .ret_index

.class1:
	mov ecx, 1
	jmp .ret_index

.class3:
	mov ecx, 3
	jmp .ret_index

.class4:
	mov ecx, 4
	jmp .ret_index

.class6:
	mov ecx, 6
	jmp .ret_index

.class7:
	mov ecx, 7
	jmp .ret_index

.class9:
	mov ecx, 9
	jmp .ret_index

.class10:
	mov ecx, 10
	jmp .ret_index

.class11:
	mov ecx, 11
.ret_index:
	push edx

	lea eax, [ecx + ecx * 2]
	shl eax, 3
	add eax, mm_slub_caches

	pop edx
	ret
