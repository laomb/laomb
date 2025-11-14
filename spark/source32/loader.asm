use32

continue_boot32:
	mov esi, kernel_bounce_buffer_flat
	call lbf_size_from_ptr
	jc lbf_size_from_ptr_error

	print '[continue_boot32] Kernel physical memory size: 0x', eax, 10

	call find_kernel_region
	jc no_region_found

	print '[continue_boot32] Kernel physical memory base: 0x', edi, ' region base: 0x', ebx, '-0x', ecx, 10
	panic '[continue_boot32] Not implemented'

no_region_found:
	panic 'Failed to find a suitable region for kernel!'

use16
