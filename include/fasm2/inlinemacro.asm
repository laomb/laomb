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

define inlinemacro? inlinemacro

calminstruction inlinemacro?! declaration&
	local	name
	match	name(arguments?), declaration
	jyes	define
	match	name= arguments?, declaration
	jyes	define
	match	name arguments?, declaration
    define:
	arrange tmp, =__inline__.name
	arrange name, =inlinemacro.name
	publish name, tmp
	arrange tmp, =struc (=return?) name arguments
	assemble tmp
end calminstruction

macro end?.inlinemacro?!
	end struc
end macro

macro inlinemacro?.enable?
	calminstruction ?! &text&
		local	head, tail, name, arguments, more, i
		init	i, 0
		match	=inlinemacro? more, text
		jyes	ready
		transform text, inlinemacro
		jno	ready
		match	=else? more, text
		jno	preprocess
		compute i, i+1
		arrange text, =__inline__.(=else =if 1) =__inline__.(=__return__.i==1) text =__inline__.(=end =if) =__inline__.(=if ~=definite =__return__.i)
	    preprocess:
		match	head? =__inline__.name?(tail?, text
		jno	ready
		match	arguments?) tail?, tail
		jno	ready
	    collect:
		match	arguments?, arguments, ()
		jyes	inline
		match	more?) tail?, tail
		jno	ready
		arrange arguments, arguments) more
		jump	collect
	    inline:
		match	, name
		jyes	special
		local	tmp, return
		compute i, i+1
		arrange return, =__return__.i
		arrange tmp, return =inlinemacro.name arguments
		arrange text, head return tail
		take	text, tmp
		jump	preprocess
	    special:
		arrange text, head tail
		take	text, arguments
		jump	preprocess
	    ready:
		assemble text
		take	, text
		take	text, text
		jyes	preprocess
	end calminstruction
end macro

macro include? file*
	include file, inlinemacro.enable
	purge ?
end macro

inlinemacro.enable
