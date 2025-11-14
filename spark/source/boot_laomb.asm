

continue_boot16:
	call load_kernel_bytes

	cli
	call enable_a20
	lgdt [gdt_descriptor]

	mov eax, cr0
	or al, 1
	mov cr0, eax

	jmp far 0x8:.cb32

use32
.cb32:
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov ss, ax

	movzx ebx, sp
	mov eax, stack_segment shl 0x4
	add eax, ebx

	mov esp, eax

	jmp continue_boot32
use16



load_kernel_bytes:
	call locate_kernel
	jc .not_found

	mov ecx, ebx
	add ecx, 511
	and ecx, 0xFFFFFE00

	mov ax, kernel_bounce_buffer_segment
	mov es, ax
	mov di, kernel_bounce_buffer_offset


	call fat12_read_file
	jc .fail

	ret

.fail:
	panic '[load_kernel_bytes] failed to load loom!'
.not_found:
	panic '[load_kernel_bytes] loom not found.'



locate_kernel:
	mov si, loom_name
	call fat12_find_file
	jnc .found

	stc
.found:
	ret



enable_a20:
	call a20_wait_input
	mov al, KBD_CONTROLLER_DISABLE_KEYBOARD
	out KBD_CONTROLLER_COMMAND_PORT, al

	call a20_wait_input
	mov al, KBD_CONTROLLER_READ_CTRL_OUTPUT_PORT
	out KBD_CONTROLLER_COMMAND_PORT, al

	call a20_wait_output
	in al, KBD_CONTROLLER_DATA_PORT
	push eax

	call a20_wait_input
	mov al, KBD_CONTROLLER_WRITE_CTRL_OUTPUT_PORT
	out KBD_CONTROLLER_COMMAND_PORT, al

	call a20_wait_input
	pop eax
	or al, 2
	out KBD_CONTROLLER_DATA_PORT, al

	call a20_wait_input
	mov al, KBD_CONTROLLER_ENABLE_KEYBOARD
	out KBD_CONTROLLER_COMMAND_PORT, al

	call a20_wait_input
	ret



a20_wait_input:
	in al, KBD_CONTROLLER_COMMAND_PORT
	test al, 2
	jnz a20_wait_input

	ret



a20_wait_output:
	in al, KBD_CONTROLLER_COMMAND_PORT
	test al, 1
	jz a20_wait_output

	ret


loom_name: db 'LOOM    BIN'

macro gdt_entry name, base, limit, access, flags
	local lim_lo, lim_hi, base_lo, base_mid, base_hi, gran

name:
	dw limit and 0xFFFF
	dw base and 0xFFFF
	db (base shr 16) and 0xFF
	db access
	db (flags and 0xF0) or ((limit shr 16) and 0x0F)
	db (base shr 24) and 0xFF
end macro

gdt_start:
	gdt_null: dq 0
	gdt_entry gdt_code32, 0x0000, 0xFFFFF, 0x9A, 0xC0
	gdt_entry gdt_data32, 0x0000, 0xFFFFF, 0x92, 0xC0
gdt_end:

gdt_descriptor:
	dw gdt_end - gdt_start - 1
	dd gdt_start

purge gdt_entry

KBD_CONTROLLER_DATA_PORT = 0x60
KBD_CONTROLLER_COMMAND_PORT = 0x64
KBD_CONTROLLER_DISABLE_KEYBOARD = 0xAD
KBD_CONTROLLER_ENABLE_KEYBOARD = 0xAE
KBD_CONTROLLER_READ_CTRL_OUTPUT_PORT = 0xD0
KBD_CONTROLLER_WRITE_CTRL_OUTPUT_PORT = 0xD1

SYSTEM_CTRL_PORT_A = 0x92
SYSTEM_CTRL_A20_BIT = 1
SYSTEM_CTRL_INIT_BIT = 0
