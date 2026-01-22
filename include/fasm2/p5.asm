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

calminstruction element? definition
	local	name, meta
	match	=tr? any, definition
	jyes	skip
	arrange definition, =element? definition
	assemble definition
	skip:
end calminstruction

include '80486.asm'

purge element?

iterate <instr,opcode>, wrmsr,<0Fh,30h>, rdtsc,<0Fh,31h>, rdmsr,<0Fh,32h>, rdpmc,<0Fh,33h>, cpuid,<0Fh,0A2h>, rsm,<0Fh,0AAh>

	calminstruction instr?
		asm	db opcode
	end calminstruction

end iterate

calminstruction cmpxchg8b? dest*
	call	x86.parse_operand@dest, dest
	check	@dest.type = 'mem'
	jyes	operand_ok
	err	'invalid operand'
	exit
	operand_ok:
	check	@dest.size and not 8
	jno	size_ok
	err	'invalid operand size'
	size_ok:
	xcall	x86.store_instruction@dest, <0Fh,0C7h>,(1)
end calminstruction

include '80387.asm'
