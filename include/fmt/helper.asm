
macro fmt__str_len dest*, txt&
	local size

	virtual at 0
		db txt
		size = $
	end virtual

	dest = size
end macro

macro fmt__str_char_at dest*, idx*, txt&
	local byte_val, size, str

	virtual at 0
	str::
		db txt
		size = $
	end virtual

	if idx < size
		load byte_val:byte from str:idx
	else
		byte_val := 0
	end if

	dest = byte_val
end macro

macro fmt__str_sub dest*, start*, len*, txt&
	local size, str, chunk

	virtual at 0
	str::
		db txt
		size = $		
	end virtual

	if len > 0
		load chunk:len from str:start
	else
		chunk = ''
	end if

	define dest chunk
end macro

macro fmt__arg_at dest*, index*, args&
	local found
	found = 0
	
	iterate arg, args
		if %-1 = index
			define dest arg
			found = 1
			break
		end if
	end iterate
	
	if found = 0
		define dest
	end if
end macro
