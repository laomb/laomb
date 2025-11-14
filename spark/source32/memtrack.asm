use32



macro __bitmap_addr_from_block32
	mov ebx, esi
	mov ecx, esi
	shr ebx, 3
	and ecx, 7
	mov dl, 1
	shl dl, cl
	add ebx, heap_base

	assert "[__bitmap_addr_from_block32] bx overflow", ebx lt heap_limit
	assert "[__bitmap_addr_from_block32] bx underflow", ebx gte heap_base
end macro

