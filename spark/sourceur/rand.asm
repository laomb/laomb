
; [out] EAX = random number
rng_get:
	push ebx

	mov eax, [rng_state]

	; if eax is 0, the algorithm gets stuck.
	test eax, eax
	jnz .do_shift

	; fallback to hardcoded seed.
	mov eax, 0xDEADBEEF
.do_shift:
	; x ^= x << 13
	mov ebx, eax
	shl ebx, 13
	xor eax, ebx

	; x ^= x >> 17
	mov ebx, eax
	shr ebx, 17
	xor eax, ebx

	; x ^= x << 5
	mov ebx, eax
	shl ebx, 5
	xor eax, ebx

	mov [rng_state], eax

	pop ebx
	ret

gather_entropy:
	push eax ecx edx esi

	mov esi, [rng_state]

	; loop counter, 32 samples are enough.
	mov cx, 32
.loop:
	; read the time stamp counter into EDX:EAX
	rdtsc

	; mix in the tsc bits into the accumulator.
	xor esi, eax

	; spread bits out.
	rol esi, 5

	; read the PIT channel 0 data port.
	; also slows down the cpu as it has to wait for the sluggish ISA bus.
	in al, 0x40

	; ensure bit spread at least to some extent.
	xor ah, al

	; accumulate.
	xor si, ax

	; serialize and slow down the CPU even more.
	push cx
	xor eax, eax
	cpuid
	pop cx

	loop .loop

	mov [rng_state], esi

	pop esi edx ecx eax
	ret

rng_state dd 0xDEADBEEF
