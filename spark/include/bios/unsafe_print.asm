
define endl 13, 10

unsafe_print_lstr__count = 0
unsafe_print_lstr__total = 0
define unsafe_print_lstr__out

macro unsafe_print str&
	local __size, out_ln

	virtual at 0
		db str
		__size = $
	end virtual

	if unsafe_print_lstr__count = 0
		redefine unsafe_print_lstr__out str
	else
		define unsafe_print_lstr__out unsafe_print_lstr__out, str
	end if

	label out_ln at unsafe_print_lstr__base + unsafe_print_lstr__total

	unsafe_print_lstr__total = unsafe_print_lstr__total + __size
	unsafe_print_lstr__count = unsafe_print_lstr__count + 1

	mov si, out_ln
	call puts
end macro
