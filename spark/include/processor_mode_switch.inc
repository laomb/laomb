macro enter_real_mode {
use32
    jmp GDT_SEL_CODE16:@f

@@:
use16
    mov eax, cr0
    and al, 0FEh
    mov cr0, eax

    jmp 0x0000:@f

@@:
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    sti
}

macro enter_protected_mode {
    cli

    lgdt [gdt_descriptor]

    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp GDT_SEL_CODE32:@f

@@:
use32
    mov ax, GDT_SEL_DATA32
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
}

macro linear_to_seg_off linear, segreg, reg32, reg16 { ; reg16 should be lower bits of reg32
    mov reg32, linear
    shr reg32, 4

    mov segreg, reg16
    mov reg32, linear
    and reg32, 0x0F
}
