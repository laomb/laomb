; flat assembler 2
; flat assembler g
; Copyright (c) 1999-2025, Tomasz Grysztar
; All rights reserved.

; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;     * Redistributions of source code must retain the above copyright
;       notice, this list of conditions and the following disclaimer.
;     * Redistributions in binary form must reproduce the above copyright
;       notice, this list of conditions and the following disclaimer in the
;       documentation and/or other materials provided with the distribution.
;     * The name of the author may not be used to endorse or promote products
;       derived from this software without specific prior written permission.

; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL Tomasz Grysztar BE LIABLE FOR ANY
; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


include '80386.asm'

purge loadall?
purge xbts?,ibts?

iterate <instr,ext>, cmpxchg,0B0h, xadd,0C0h

	calminstruction instr? dest*,src*
		call	x86.parse_operand@dest, dest
		call	x86.parse_operand@src, src
		check	@src.type = 'reg' & ( @dest.type = 'reg' | @dest.type = 'mem' )
		jyes	xadd_rm_reg
		err	'invalid combination of operands'
		exit
		xadd_rm_reg:
		check	@dest.size and not @src.size
		jno	size_ok
		err	'operand sizes do not match'
		  size_ok:
		check	@src.size > 1
		jno	xadd_rm_reg_8bit
		call	x86.select_operand_prefix@dest, @src.size
		xcall	x86.store_instruction@dest, <0Fh,ext+1>,@src.rm
		exit
		  xadd_rm_reg_8bit:
		xcall	x86.store_instruction@dest, <0Fh,ext>,@src.rm
	end calminstruction

end iterate

calminstruction bswap? dest*
	call	x86.parse_operand@dest, dest
	check	@dest.type = 'reg' & @dest.size = 4
	jyes	operand_ok
	err	'invalid operand'
	exit
	operand_ok:
	call	x86.store_operand_prefix, @dest.size
	emit	1, 0Fh
	emit	1, 0C8h + @dest.rm and 111b
end calminstruction

calminstruction invlpg? dest*
	call	x86.parse_operand@dest, dest
	check	@dest.type = 'mem'
	jyes	operand_ok
	err	'invalid operand'
	exit
	operand_ok:
	xcall	x86.store_instruction@dest, <0Fh,1>,(7)
end calminstruction

iterate <instr,opcode>, invd,<0Fh,8>, wbinvd,<0Fh,9>

	define x86.instr? db opcode

	calminstruction instr?
		assemble x86.instr?
	end calminstruction

end iterate
