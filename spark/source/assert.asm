


assert_fail_rmode:
	push si
	
	mov si, str_assert_fail
	call print_str_rmode

	pop si
	jmp panic_rmode

str_assert_fail: db 10, 'ASSERT FAILED', 0
