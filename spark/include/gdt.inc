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