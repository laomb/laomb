use32

continue_boot32:
	call vga_clear_pmode

	mov esi, kernel_bounce_buffer_flat
	call lbf_size_from_ptr
	jc lbf_size_from_ptr_error

	print '[continue_boot32] Kernel physical memory size: 0x', eax, 10

	call find_kernel_region
	jc no_region_found

	print '[continue_boot32] Kernel physical memory base: 0x', edi, ' region base: 0x', ebx, '-0x', ecx, 10

	call e820_reserve_kernel
	jc failed_to_reserve_e820

	panic '[continue_boot32] Not implemented'

no_region_found:
	panic 'Failed to find a suitable region for kernel!'
failed_to_reserve_e820:
	panic 'Failed to reserve kernel region in e820 memory map!'

use16
