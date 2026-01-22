macro @@ line&
	match label, @f?
		label line
		@b?. equ @f?
	end match
	local anon
	@f?. equ anon
end macro

define @f?
@@
