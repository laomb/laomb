define endl 13, 10

macro clsscr_rm
{
    pushad
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    popad
}

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


macro gdt_entry name, base, limit, access, flags {
    local lim_lo, lim_hi, base_lo, base_mid, base_hi, gran

    lim_lo = limit and 0xFFFF
    lim_hi = (limit shr 16) and 0x0F
    base_lo = base and 0xFFFF
    base_mid = (base shr 16) and 0xFF
    base_hi = (base shr 24) and 0xFF
    gran = (flags and 0xF0) or lim_hi

name:
    dw lim_lo
    dw base_lo
    db base_mid
    db access
    db gran
    db base_hi
}