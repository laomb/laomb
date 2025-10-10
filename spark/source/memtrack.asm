
block_shift = 4
block_size = 1 shl block_shift

total_blocks = heap_size shr block_shift
bitmap_bytes = (total_blocks + 7) shr 3
bitmap_blocks = (bitmap_bytes + block_size - 1) shr block_shift

data_first_block = bitmap_blocks
magic_word = 0x4D4D

; In: SI = block index
; Out: BX = offset to bitmap byte, CL = bit number (0..7), DL = bit mask
macro __bitmap_addr_from_block
	mov bx, si
	mov cx, si

	shr bx, 3
	and cx, 7

	mov dl, 1
	shl dl, cl

	add bx, heap_base
	assert "[__bitmap_addr_from_block]: bx overflow", bx lt heap_limit
	assert "[__bitmap_addr_from_block]: bx underflow", bx gte heap_base
end macro


; In: SI = block index
; Out: ZF=1 if free, ZF=0 if used, AL = bitmap byte, DL = bit mask
is_block_used:
	push si

	__bitmap_addr_from_block
	mov al, [bx]
	test al, dl

	pop si
	ret


; In: SI = block index
mark_block_used:
	pusha

	assert "[mark_block_used]: invalid block index", si lt total_blocks

	__bitmap_addr_from_block
	mov al, [bx]
	or al, dl
	mov [bx], al

	popa
	ret


; In: SI = block index
mark_block_free:
	pusha

	assert "[mark_block_free]: invalid block index", si lt total_blocks

	__bitmap_addr_from_block
	mov al, [bx]
	not dl
	and al, dl
	not dl
	mov [bx], al
	
	popa 
	ret


; In: CX = number of contiguous free blocks requested
; Out: CF=0 -> SI = header_block_index ; CF=1 -> not found
find_free_run:
	assert "[find_free_run]: cx=0 invalid", cx gt 0

	push dx di

	xor di, di
	mov si, data_first_block
.ffr_next:
	cmp si, total_blocks
	jae .ffr_fail

	push cx
	call is_block_used
	pop cx
	jnz .used

	cmp di, 0
	jne .cont
	
	mov dx, si
.cont:
	inc di
	cmp di, cx

	je .ok
	inc si
	jmp .ffr_next

.used:
	xor di, di
	inc si
	jmp .ffr_next

.ok:
	mov si, dx
	clc

	pop di dx
	ret

.ffr_fail:
	stc
	pop di dx

	ret



mem_init:
	pusha

	assert "[mem_init] invalid segments!", es eq ds, ds eq 0

	mov di, heap_base
	mov cx, bitmap_bytes
	xor al, al
	rep stosb

	xor si, si
.init_mark_loop:
	cmp si, bitmap_blocks
	jae .done_mark

	call mark_block_used
	inc si
	
	jmp .init_mark_loop

.done_mark:
	popa
	ret


; In: AX = bytes to allocate
; Out: CF=0 -> AX = offset to user memory (aligned 16B)
;      CF=1 -> fail
mem_alloc:
	push dx cx bx si di

	add ax, (block_size - 1)
	shr ax, block_shift
	mov cx, ax

	inc cx
	call find_free_run
	jc .fail

	mov dx, si
	mov di, cx
.mark_loop:
	call mark_block_used

	inc si
	dec di

	jnz .mark_loop

	mov bx, dx
	shl bx, block_shift
	add bx, heap_base

	mov word [bx], cx
	mov word [bx + 2], magic_word

	mov ax, dx

	inc ax
	shl ax, block_shift
	add ax, heap_base
	
	clc
	pop di si bx cx dx
	ret

.fail:
	stc
	pop di si bx cx dx
	ret


; In: AX = pointer to memory to free
; Out: CF=0 -> ok ; CF=1 -> error
mem_free:
	pusha
	assert "[mem_free]: invalid free", ax gte heap_base, ax lt heap_limit

	mov bx, ax
	sub bx, heap_base
	shr bx, block_shift

	assert "[mem_free]: attempted free in bitmap", bx gt data_first_block
	dec bx

	mov si, bx

	shl si, block_shift
	add si, heap_base
	mov cx, [si]
	mov ax, [si + 2]
	assert "[mem_free]: heap corruption", ax eq magic_word

	mov si, bx
.free_loop:
	call mark_block_free
	inc si
	dec cx

	jnz .free_loop

	clc
	popa
	ret


; Out: BX = free, CX = used
mem_stats:
	push ax di si
	xor bx, bx
	xor cx, cx

	mov si, data_first_block
.ms_loop:
	cmp si, total_blocks
	jae .ms_done

	call is_block_used
	jnz .used
	inc bx
	jmp .next

.used:
	inc cx
.next:
	inc si
	jmp .ms_loop

.ms_done:
	pop si di ax
	ret
