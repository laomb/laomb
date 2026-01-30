define SMAP_MAGIC 0x534D4150

; [out] SI = number of entries
memmap_init:
	xor si, si
	xor ebx, ebx
	mov edi, e820_buffer
.loop:
	inc si
	mov eax, 0xE820
	mov ecx, 20 ; TODO can increase
	mov edx, SMAP_MAGIC

	int 0x15

	jc .error_int
	cmp eax, SMAP_MAGIC
	jne .error_magic

	add di, cx

	print 'E820 Continuation '
	mov eax, ebx
	call print_hex16_16
	print 10

	test ebx, ebx
	jnz .loop

	mov [memmap_entry_count], si

	ret

.error_int:
	print 'Error in int 15', 10
	jmp $

.error_magic:
	print 'Invalid magic number', 10
	jmp $

memmap_entry_count: dw 0
