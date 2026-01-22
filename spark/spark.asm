org 0x500

include 'bios/unsafe_print.asm'

_start:
    unsafe_print "Hello from stage 2!", 13, 10, 0
    jmp $

puts:
	lodsb
	test al, al
	jz .done

	mov ah, 0xe
	xor bh, bh
	int 0x10

	jmp puts

.done:
	ret

if defined unsafe_print_lstr__count & (unsafe_print_lstr__count > 0)
	unsafe_print_lstr__base = $
	db unsafe_print_lstr__out
end if
