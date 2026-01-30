
ldr_load_loom:
	call rng_get
	and eax, 0xFFFF
	print 'PASLR rng: ', eax, 10

	call paslr_find_usable
	print 'PASLR found usable: ', eax, 10

	print 'Loading loom...', 10
    jmp $
