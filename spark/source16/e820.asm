
SMAP_MAGIC = 0x534D4150

E820_ENTRY_SIZE = 20
E820_MAX_ENTRIES = (4096 / E820_ENTRY_SIZE)

struct e820_entry
	base dq ?
	length dq ?
	type dd ?
end struct

E820_TYPE_USABLE = 1
E820_TYPE_RESERVED = 2
E820_TYPE_ACPI_RECLAIMABLE = 3
E820_TYPE_ACPI_NVS = 4
E820_TYPE_BAD = 5

e820_init:
	; prepare the buffer pointer and guard.
	mov di, e820_buffer
	mov bp, E820_MAX_ENTRIES

	; continuation value starts at 0.
	xor ebx, ebx
.e820_loop:
	; GET SYSTEM MEMORY MAP
	; EDX = 534D4150h ('SMAP')
	; EBX = continuation value
	; ECX = size of buffer for result
	; ES:DI -> buffer for result
	mov eax, 0xe820
	mov edx, SMAP_MAGIC
	mov ecx, E820_ENTRY_SIZE
	int 0x15
	jc .done_e820

	cmp eax, SMAP_MAGIC
	jne .done_e820

	inc byte [e820_entry_count]

	; move pointer to the next entry.
	add di, E820_ENTRY_SIZE

	; guard to not wrap to IVT.
	dec bp
	jz .done_e820

	; if continuation value is back to 0, stop.
	test ebx, ebx
	jnz .e820_loop

.done_e820:
	ret

e820_entry_count: db 0
