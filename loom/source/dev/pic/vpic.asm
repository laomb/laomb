VPIC_NUM_LINES = 16

VPIC_FLAG_CLAIMED = 1
VPIC_FLAG_ENABLED = 2
VPIC_FLAG_UMSK = 4
VPIC_FLAG_QUEUED = 8

VPIC_TH_MASK_LINE = 1
VPIC_TH_TIE_KNOT = 2

struct VpicLine
	handler dd ?
	knot_handler dd ?

	context dd ?
	flags dd ?

	knot Knot
end struct

segment 'TEXT', ST_CODE_XO

; procedure vpic$init();
vpic$init:
	push edi ds es

	mov ax, rel 'DATA'
	mov ds, ax
	mov es, ax

	; zero out all virtual line state.
	lea edi, [vpic$lines]
	mov ecx, (sizeof.VpicLine * VPIC_NUM_LINES) / dword
	xor eax, eax
	cld
	rep stosd

	; initialize the real 8259 hardware.
	call pic$init

	; register vpic$_irq_entry as the idt handler for vectors 32..47.
	mov ecx, VPIC_NUM_LINES
	mov al, PIC_MASTER_OFFSET
.reg_loop:
	lea edx, [vpic$_irq_entry]
	call idt$register_handler

	inc al
	dec ecx

	jnz .reg_loop

	pop es ds edi
	ret

; function vpic$request(irq: Byte, handler: Cardinal, knot_handler: Cardinal, context: Cardinal): CF;
vpic$request:
	push ebx esi ds

	mov bx, rel 'DATA'
	mov ds, bx

	movzx ebx, al
	cmp ebx, VPIC_NUM_LINES
	jae .fail

	; calculate the VpicLine pointer.
	mov esi, ebx
	imul esi, sizeof.VpicLine
	add esi, vpic$lines

	; check if the line is already claimed.
	test dword [esi + VpicLine.flags], VPIC_FLAG_CLAIMED
	jnz .fail

	mov eax, dword [esp + 16]

	; populate the line.
	mov dword [esi + VpicLine.handler], edx
	mov dword [esi + VpicLine.knot_handler], ecx
	mov dword [esi + VpicLine.context], eax
	or dword [esi + VpicLine.flags], VPIC_FLAG_CLAIMED

	; wire the embedded knot to point at our deferred dispatcher.
	lea eax, [vpic$_knot_handler]
	mov dword [esi + VpicLine.knot + Knot.handler], eax

	; store the irq number as the knot context so the deferred handler knows which line fired.
	mov dword [esi + VpicLine.knot + Knot.context], ebx

	clc
	pop ds esi ebx
	ret 4

.fail:
	stc
	pop ds esi ebx
	ret 4

; procedure vpic$release(irq: Byte);
vpic$release:
	push ebx esi ds

	mov bx, rel 'DATA'
	mov ds, bx

	movzx ebx, al
	cmp ebx, VPIC_NUM_LINES
	jae .done

	; first mask the line on real hardware.
	call pic$mask

	; calculate the VpicLine pointer.
	mov esi, ebx
	imul esi, sizeof.VpicLine
	add esi, vpic$lines

	; zero the VpicLine.
	mov dword [esi + VpicLine.handler], 0
	mov dword [esi + VpicLine.knot_handler], 0
	mov dword [esi + VpicLine.context], 0
	mov dword [esi + VpicLine.flags], 0

.done:
	pop ds esi ebx
	ret

; procedure vpic$enable(irq: Byte);
vpic$enable:
	push ebx esi ds

	mov bx, rel 'DATA'
	mov ds, bx

	movzx ebx, al
	cmp ebx, VPIC_NUM_LINES
	jae .done

	; calculate the VpicLine pointer.
	mov esi, ebx
	imul esi, sizeof.VpicLine
	add esi, vpic$lines

	; must be claimed.
	test dword [esi + VpicLine.flags], VPIC_FLAG_CLAIMED
	jz .done

	; enable it.
	or dword [esi + VpicLine.flags], VPIC_FLAG_ENABLED

	; unmask on real hardware.
	mov al, bl
	call pic$unmask

.done:
	pop ds esi ebx
	ret

; procedure vpic$disable(irq: Byte);
vpic$disable:
	push ebx esi ds

	mov bx, rel 'DATA'
	mov ds, bx

	movzx ebx, al
	cmp ebx, VPIC_NUM_LINES
	jae .done

	; calculate the VpicLine pointer.
	mov esi, ebx
	imul esi, sizeof.VpicLine
	add esi, vpic$lines

	; disable it.
	and dword [esi + VpicLine.flags], not VPIC_FLAG_ENABLED

	; mask on real hardware.
	mov al, bl
	call pic$mask

.done:
	pop ds esi ebx
	ret

; procedure vpic$_irq_entry(frame_ptr: ^InterruptFrame);
vpic$_irq_entry:
	mov bx, rel 'DATA'
	mov ds, bx

	; derive the IRQ number from the vector in the interrupt frame.
	mov ebx, dword [ss:eax + InterruptFrame.vector]
	sub ebx, PIC_MASTER_OFFSET

	cmp ebx, VPIC_NUM_LINES
	jae .spurious

	; calculate VpicLine pointer.
	mov esi, ebx
	imul esi, sizeof.VpicLine
	add esi, vpic$lines

	; if line is not claimed, treat as spurious.
	test dword [esi + VpicLine.flags], VPIC_FLAG_CLAIMED
	jz .spurious

	; dispatch the top level handler.
	mov eax, dword [esi + VpicLine.context]
	mov dl, bl
	call dword [esi + VpicLine.handler]

	; does the ISR handler want to tie a knot?
	test eax, VPIC_TH_TIE_KNOT
	jz .no_knot

	; is there a knot handler even registered?
	cmp dword [esi + VpicLine.knot_handler], 0
	je .no_knot

	; if the knot is already queued, skip, otherwise set the bit and continue.
	bts dword [esi + VpicLine.flags], 3
	jc .no_knot

	push eax

	; tie the embedded knot, shuttle will call vpic$_knot_handler at EL_1.
	lea eax, [esi + VpicLine.knot]
	call shuttle$tie

	pop eax
.no_knot:
	test eax, VPIC_TH_MASK_LINE
	jz .send_eoi

	; mask the line on real hardware to prevent re-entry before the deferred handler has run.
	mov al, bl
	call pic$mask

	; notify the knot handler to unmask the line once handler runs.
	or dword [esi + VpicLine.flags], VPIC_FLAG_UMSK
.send_eoi:
	; send EOI so other interrupts can fire while we defer this one.
	mov al, bl
	call pic$send_eoi

	ret

.spurious:
	cmp bl, 7
	je .check_hw_spurious

	cmp bl, 15
	je .check_hw_spurious
.send_spurious_eoi:
	mov al, bl
	call pic$send_eoi

.hw_spurious_done:
	ret

.check_hw_spurious:
	; is this a real IRQ?
	call pic$get_isr
	bt eax, ebx
	jc .send_spurious_eoi

	; IRQ 15 has to send an EOI to the master pic.
	cmp bl, 15
	jne .hw_spurious_done

	; any value <8 routes to master.
	mov al, 7
	call pic$send_eoi

	jmp .hw_spurious_done

; procedure vpic$_knot_handler(irq: Cardinal);
vpic$_knot_handler:
	push esi ds

	mov bx, rel 'DATA'
	mov ds, bx

	cmp eax, VPIC_NUM_LINES
	jae .done

	; calculate VpicLine pointer.
	mov esi, eax
	imul esi, sizeof.VpicLine
	add esi, vpic$lines

	push eax

	; clear the queued flag.
	btr dword [esi + VpicLine.flags], 3

	; call the driver's handler: handler(context, irq).
	mov edx, eax
	mov eax, dword [esi + VpicLine.context]
	call dword [esi + VpicLine.knot_handler]

	pop eax

	; is the line still marked as enabled?
	test dword [esi + VpicLine.flags], VPIC_FLAG_ENABLED
	jz .done

	; did the ISR request an unmask?
	btr dword [esi + VpicLine.flags], 2
	jnc .done

	; re-enable it in hardware.
	call pic$unmask
.done:
	pop ds esi
	ret

segment 'DATA', ST_DATA_RW

vpic$lines:
	rb sizeof.VpicLine * VPIC_NUM_LINES
