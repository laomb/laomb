
E820_BASE_LOW = 0
E820_BASE_HIGH = 4
E820_LENGTH_LOW = 8
E820_LENGTH_HIGH = 12
E820_TYPE = 16
E820_ENTRY_SIZE = 20
E820_TYPE_USABLE = 1

E820_MAX_ENTRIES = (4096 / E820_ENTRY_SIZE)



e820_init:
	pusha

	xor ax, ax
	mov di, e820_buffer
	mov bp, E820_MAX_ENTRIES

	xor ebx, ebx
.e820_loop:
	mov eax, 0xe820
	mov edx, 0x534d4150
	mov ecx, E820_ENTRY_SIZE

	int 0x15
	jc .done_e820
	cmp eax, 0x534d4150
	jne .done_e820

	inc byte [e820_entry_count]

	add di, E820_ENTRY_SIZE
	dec bp
	jz .done_e820

	test ebx, ebx
	jnz .e820_loop

.done_e820:
	popa
	ret


e820_entry_count db 0
