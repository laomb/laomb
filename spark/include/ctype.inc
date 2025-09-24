
; in al -> char
macro is_alpha true_label, false_label
{
	mov dl, al
	or dl, 0x20
	sub dl, 'a'
	
	cmp dl, 'z' - 'a'
	jbe true_label
	jmp false_label
}

; in al -> char
macro is_alnum true_label, false_label
{
	mov dl, al
	or dl, 0x20
	sub dl, 'a'

	cmp dl, 'z' - 'a'
	jbe true_label

	mov dl, al
	sub dl, '0'

	cmp dl, '9' - '0'
	jbe true_label

	jmp false_label
}

; in al -> char
macro is_digit true_label, false_label
{
	mov dl, al
	sub dl, '0'
	
	cmp dl, '9' - '0'
	jbe true_label
	jmp false_label
}

; in al -> char to uppercase
; out al -> uppercased char
macro to_upper
{
	local .done
	cmp al, 'a'
	jb .done
	cmp al, 'z'
	ja .done
	sub al, 32
.done:
}

; in al -> char to lower
; out al -> lowered char
macro to_lower
{
	local .done
	cmp al, 'A'
	jb .done
	cmp al, 'Z'
	ja .done
	add al, 32
.done:
}

; in al -> char to find
; 	 src_reg -> pointer to strign
; out out_reg -> pointer to found char or 0
macro strchr out_reg, src_reg
{
	local .loop, .found, .nf, .done

	push edx
	mov out_reg, src_reg

.loop:
	mov dl, [out_reg]
	cmp dl, al
	je .found
	test dl, dl
	je .nf
	inc out_reg
	jmp .loop

.found:
	pop edx
	jmp .done

.nf:
	xor out_reg, out_reg
	pop edx

.done:
}
